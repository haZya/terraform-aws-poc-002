import type { APIGatewayEventWebsocketRequestContextV2, APIGatewayProxyWebsocketEventV2WithRequestContext, Handler } from "aws-lambda";
import { ConditionalCheckFailedException, DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DeleteCommand, DynamoDBDocumentClient, PutCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import type { AuthorizerResultContext } from "./authorizer";

const client = new DynamoDBClient({});
const db = DynamoDBDocumentClient.from(client);
const tableName = process.env.CONNECTIONS_TABLE_NAME;

const USER_PK_PREFIX = "USER#";
export const CONN_SK_PREFIX = "CONN#";

export const getPk = (userId: string) => `${USER_PK_PREFIX}${userId}`;

const getSk = (connectionId: string) => `${CONN_SK_PREFIX}${connectionId}`;
const getTtl = () => Math.floor(Date.now() / 1000) + (60 * 60 * 2);

interface ConnectionItem {
  PK: string;
  SK: string;
  connectionId: string;
  ttl: number;
}

export const handler: Handler<APIGatewayProxyWebsocketEventV2WithRequestContext<APIGatewayEventWebsocketRequestContextV2 & { authorizer: AuthorizerResultContext }>> = async (event) => {
  const { requestContext } = event;
  const { authorizer, connectionId, routeKey } = requestContext;
  const { userSub } = authorizer;

  if (!userSub) {
    return {
      statusCode: 401,
      body: JSON.stringify({ error: "Authorized user not found" }),
    };
  }

  try {
    switch (routeKey) {
      case "$connect":
        await saveConnection(userSub, connectionId);
        return { statusCode: 200 };
      case "$disconnect":
        await removeConnection(userSub, connectionId);
        return { statusCode: 200 };
      case "message":
        await refreshConnectionTtl(userSub, connectionId);
        return { statusCode: 200 };
      default:
        return {
          statusCode: 400,
          body: JSON.stringify({ error: `Invalid action: ${routeKey}` }),
        };
    }
  }
  catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({ message: (error as Error).message }),
    };
  }
};

export async function saveConnection(userSub: string, connectionId: string): Promise<void> {
  const item: ConnectionItem = {
    PK: getPk(userSub),
    SK: getSk(connectionId),
    connectionId,
    ttl: getTtl(),
  };

  try {
    await db.send(new PutCommand({
      TableName: tableName,
      Item: item,
    }));
    console.info(`Connection ${connectionId} saved for user ${userSub}`);
  }
  catch (error) {
    console.error("Error saving connection:", error);
    throw new Error("Failed to establish a connection");
  }
}

export async function removeConnection(userSub: string, connectionId: string): Promise<void> {
  try {
    await db.send(new DeleteCommand({
      TableName: tableName,
      Key: {
        PK: getPk(userSub),
        SK: getSk(connectionId),
      },
    }));
    console.info(`Connection ${connectionId} removed for user ${userSub}`);
  }
  catch (error) {
    console.error("Error removing connection:", error);
    throw new Error("Failed to remove the connection");
  }
}

export async function refreshConnectionTtl(userSub: string, connectionId: string): Promise<void> {
  try {
    await db.send(new UpdateCommand({
      TableName: tableName,
      Key: {
        PK: getPk(userSub),
        SK: getSk(connectionId),
      },
      UpdateExpression: "SET #T = :newTtl",
      ExpressionAttributeNames: {
        "#T": "ttl",
      },
      ExpressionAttributeValues: {
        ":newTtl": getTtl(),
      },
      ReturnValues: "UPDATED_NEW",
      ConditionExpression: "attribute_exists(PK)",
    }));
    console.info(`TTL refreshed for connection ${connectionId}`);
  }
  catch (error) {
    if (error instanceof ConditionalCheckFailedException) {
      console.warn(`TTL refresh failed for connection ${connectionId}. Item was likely deleted by TTL service.`, error);
      return;
    }

    console.error(`Error updating TTL ${connectionId}:`, error);
    throw new Error("Failed to update TTL");
  }
}
