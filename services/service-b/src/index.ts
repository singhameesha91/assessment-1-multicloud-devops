/**
 * Service B - Asset Management API (TypeScript/Bun)
 * A microservice that manages application assets via GCP Cloud Storage.
 */

import { Storage } from "@google-cloud/storage";

const PORT = parseInt(process.env.PORT || "3000");
const GCP_BUCKET = process.env.GCP_BUCKET || "app-assets-bucket";
const GCP_PROJECT = process.env.GCP_PROJECT || "my-gcp-project";
const GCS_ENDPOINT = process.env.GCS_ENDPOINT; // Set for local emulator

// GCP Storage client
const storageOpts: ConstructorParameters<typeof Storage>[0] = { projectId: GCP_PROJECT };
if (GCS_ENDPOINT) {
  storageOpts.apiEndpoint = GCS_ENDPOINT;
}
const storage = new Storage(storageOpts);
const bucket = storage.bucket(GCP_BUCKET);

interface Asset {
  name: string;
  size: number;
  contentType: string;
  updated: string;
  url: string;
}

interface ApiResponse {
  status: number;
  body: unknown;
}

async function handleHealth(): Promise<ApiResponse> {
  return {
    status: 200,
    body: {
      status: "healthy",
      service: "service-b",
      timestamp: new Date().toISOString(),
    },
  };
}

async function handleRoot(): Promise<ApiResponse> {
  return {
    status: 200,
    body: {
      service: "service-b",
      version: "1.0.0",
      description: "Asset Management API (Bun + GCP Storage)",
    },
  };
}

async function handleListAssets(prefix?: string): Promise<ApiResponse> {
  try {
    const [files] = await bucket.getFiles({ prefix: prefix || "" });
    const assets: Asset[] = files.map((file) => ({
      name: file.name,
      size: parseInt(file.metadata.size as string) || 0,
      contentType: (file.metadata.contentType as string) || "unknown",
      updated: (file.metadata.updated as string) || "",
      url: `https://storage.googleapis.com/${GCP_BUCKET}/${file.name}`,
    }));

    return {
      status: 200,
      body: { assets, count: assets.length },
    };
  } catch (error) {
    return {
      status: 500,
      body: { error: `Failed to list assets: ${(error as Error).message}` },
    };
  }
}

async function handleUploadAsset(
  name: string,
  body: ReadableStream | null,
  contentType: string
): Promise<ApiResponse> {
  if (!name || !body) {
    return { status: 400, body: { error: "Missing asset name or body" } };
  }

  try {
    const file = bucket.file(name);
    const buffer = await Bun.readableStreamToArrayBuffer(body);
    await file.save(Buffer.from(buffer), {
      contentType,
      metadata: { uploadedAt: new Date().toISOString() },
    });

    return {
      status: 201,
      body: {
        message: "Asset uploaded successfully",
        name,
        url: `https://storage.googleapis.com/${GCP_BUCKET}/${name}`,
      },
    };
  } catch (error) {
    return {
      status: 500,
      body: { error: `Failed to upload asset: ${(error as Error).message}` },
    };
  }
}

async function handleDeleteAsset(name: string): Promise<ApiResponse> {
  if (!name) {
    return { status: 400, body: { error: "Missing asset name" } };
  }

  try {
    await bucket.file(name).delete();
    return {
      status: 200,
      body: { message: "Asset deleted successfully", name },
    };
  } catch (error) {
    return {
      status: 500,
      body: { error: `Failed to delete asset: ${(error as Error).message}` },
    };
  }
}

const server = Bun.serve({
  port: PORT,
  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);
    const path = url.pathname;
    const method = req.method;

    let result: ApiResponse;

    if (path === "/health" && method === "GET") {
      result = await handleHealth();
    } else if (path === "/" && method === "GET") {
      result = await handleRoot();
    } else if (path === "/assets" && method === "GET") {
      const prefix = url.searchParams.get("prefix") || undefined;
      result = await handleListAssets(prefix);
    } else if (path.startsWith("/assets/") && method === "PUT") {
      const name = path.slice("/assets/".length);
      const contentType = req.headers.get("content-type") || "application/octet-stream";
      result = await handleUploadAsset(name, req.body, contentType);
    } else if (path.startsWith("/assets/") && method === "DELETE") {
      const name = path.slice("/assets/".length);
      result = await handleDeleteAsset(name);
    } else {
      result = { status: 404, body: { error: "Not found" } };
    }

    return new Response(JSON.stringify(result.body), {
      status: result.status,
      headers: { "Content-Type": "application/json" },
    });
  },
});

console.log(`Service B listening on port ${server.port}`);
