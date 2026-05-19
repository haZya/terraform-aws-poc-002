import type { APIGatewayAuthorizerWithContextResult, APIGatewayRequestAuthorizerEvent, Handler } from "aws-lambda";

export interface AuthorizerResultContext {
  userSub?: string;
  [key: string]: string | number | boolean | null | undefined;
}

type AuthorizerResult = APIGatewayAuthorizerWithContextResult<AuthorizerResultContext>;
type PolicyEffect = "Allow" | "Deny";

async function verifyToken(_token: string): Promise<{ sub: string }> {
  // Demo-only mock verification. In production, verify the JWT signature and claims
  // with your identity provider before trusting and forwarding `sub`.
  return { sub: "demo-user-sub" };
}

export const handler: Handler<APIGatewayRequestAuthorizerEvent, AuthorizerResult> = async (event) => {
  const { methodArn, headers, queryStringParameters } = event;
  const token = headers?.Authorization || queryStringParameters?.token || "";
  const cleanToken = token.replace("Bearer ", "");

  try {
    const payload = await verifyToken(cleanToken);

    console.info("Token verification successful");

    return generatePolicy(payload.sub, "Allow", methodArn, { userSub: payload.sub });
  }
  catch (error) {
    console.error("Token verification failed:", error);

    return generatePolicy("unauthorized", "Deny", methodArn);
  }
};

function generatePolicy(principalId: string, effect: PolicyEffect, resource: string, context: AuthorizerResultContext = {}): AuthorizerResult {
  return {
    principalId,
    policyDocument: {
      Version: "2012-10-17",
      Statement: [
        {
          Action: "execute-api:Invoke",
          Effect: effect,
          Resource: resource,
        },
      ],
    },
    context,
  };
}
