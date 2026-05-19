import { CopyObjectCommand, S3Client } from "@aws-sdk/client-s3";

const s3 = new S3Client({ followRegionRedirects: true });
const uploadBucket = process.env.UPLOAD_BUCKET;

if (!uploadBucket) {
  throw new Error("UPLOAD_BUCKET environment variable is required");
}

export async function handler(event: { bucket: string; key: string; finalKey: string; mime: string }) {
  const copySourceKey = encodeURIComponent(event.key).replace(/%2F/g, "/");
  const result = await s3.send(new CopyObjectCommand({
    CopySource: `${event.bucket}/${copySourceKey}`,
    Bucket: uploadBucket,
    Key: event.finalKey,
    MetadataDirective: "REPLACE",
    ContentType: event.mime,
    TaggingDirective: "REPLACE",
  }));

  return {
    ...event,
    s3CopyResult: result.CopyObjectResult,
  };
}
