import { ApiGatewayManagementApi } from "@aws-sdk/client-apigatewaymanagementapi";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DeleteCommand, DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { CONN_SK_PREFIX, getPk } from "../websocket/connection";

const db = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const api = new ApiGatewayManagementApi({ endpoint: process.env.WEBSOCKET_API_ENDPOINT });

export async function handler(event: {
  key: string;
  authorSubId: string;
  status: { isSuccess: boolean; name: string; message: string };
}) {
  const tableName = process.env.CONNECTIONS_TABLE_NAME;

  const response = await db.send(new QueryCommand({
    TableName: tableName,
    KeyConditionExpression: "PK = :pk AND begins_with(SK, :sk)",
    ExpressionAttributeValues: {
      ":pk": getPk(event.authorSubId),
      ":sk": CONN_SK_PREFIX,
    },
    ProjectionExpression: "connectionId",
  }));

  const connectionIds = response.Items?.map(item => item.connectionId) ?? [];
  const failedErrors: unknown[] = [];

  await Promise.all(connectionIds.map(async (connectionId) => {
    try {
      await api.postToConnection({
        ConnectionId: connectionId,
        Data: JSON.stringify({
          type: "FileUploadStatus",
          key: event.key,
          status: event.status,
        }),
      });
    }
    catch (error) {
      if ((error as { name?: string }).name === "GoneException") {
        await db.send(new DeleteCommand({
          TableName: tableName,
          Key: {
            PK: getPk(event.authorSubId),
            SK: `${CONN_SK_PREFIX}${connectionId}`,
          },
        }));
        return;
      }

      failedErrors.push(error);
    }
  }));

  if (failedErrors.length > 0) {
    console.error("Failed to emit upload status to some connections", {
      key: event.key,
      authorSubId: event.authorSubId,
      failedCount: failedErrors.length,
    });
    throw new Error("Failed to emit upload status to one or more connections");
  }
}
