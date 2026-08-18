import { S3Client, GetObjectCommand, PutObjectCommand, DeleteObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { config } from '../config/env';

export interface StorageObjectUploadInput {
  key: string;
  body: Buffer | Uint8Array | string;
  contentType?: string;
  metadata?: Record<string, string>;
}

export class StorageService {
  private readonly client: S3Client;
  private readonly bucketName: string;

  constructor() {
    this.bucketName = config.r2.bucketName;

    this.client = new S3Client({
      region: 'auto',
      endpoint: config.r2.endpoint || `https://${config.r2.accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: config.r2.accessKeyId,
        secretAccessKey: config.r2.secretAccessKey,
      },
    });
  }

  async uploadObject({ key, body, contentType, metadata }: StorageObjectUploadInput) {
    const command = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: key,
      Body: body,
      ContentType: contentType,
      Metadata: metadata,
    });

    await this.client.send(command);

    return {
      key,
      bucket: this.bucketName,
      url: `${config.r2.publicUrl || ''}/${key}`,
    };
  }

  async getObject(key: string) {
    const command = new GetObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    return this.client.send(command);
  }

  async deleteObject(key: string) {
    const command = new DeleteObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    await this.client.send(command);
    return { deleted: true, key };
  }

  async getPresignedUrl(key: string, expiresInSeconds = 3600) {
    const command = new GetObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    return getSignedUrl(this.client, command, { expiresIn: expiresInSeconds });
  }

  async objectExists(key: string) {
    const command = new HeadObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    try {
      await this.client.send(command);
      return true;
    } catch {
      return false;
    }
  }
}
