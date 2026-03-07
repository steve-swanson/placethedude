const crypto = require("node:crypto");
const { S3Client, GetObjectCommand } = require("@aws-sdk/client-s3");
const sharp = require("sharp");

const s3 = new S3Client({});

const pathPatterns = [
  /^\/img\/(?:([a-zA-Z])\/)?(\d{2,5})\/(\d{2,5})\/?$/,
  /^\/(?:([a-zA-Z])\/)?(\d{2,5})\/(\d{2,5})\/?$/
];

function parsePositiveInteger(value, name) {
  const parsed = Number.parseInt(value, 10);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer.`);
  }

  return parsed;
}

function parseRequestPath(rawPath) {
  for (const pattern of pathPatterns) {
    const match = pattern.exec(rawPath);

    if (!match) {
      continue;
    }

    return {
      specialHandler: match[1] ? match[1].trim() : "",
      width: Number.parseInt(match[2], 10),
      height: Number.parseInt(match[3], 10)
    };
  }

  throw new Error(`Unsupported path: ${rawPath}`);
}

function buildImageKey(imageNumber, options = {}) {
  const prefix = options.prefix ?? process.env.IMAGE_KEY_PREFIX ?? "thedude-";
  const suffix = options.suffix ?? process.env.IMAGE_KEY_SUFFIX ?? ".jpg";
  const padding = options.padding ?? parsePositiveInteger(process.env.IMAGE_NUMBER_PADDING ?? "2", "IMAGE_NUMBER_PADDING");

  return `${prefix}${String(imageNumber).padStart(padding, "0")}${suffix}`;
}

function getConfig() {
  const imageBucket = process.env.IMAGE_BUCKET;

  if (!imageBucket) {
    throw new Error("IMAGE_BUCKET is required.");
  }

  return {
    imageBucket,
    imageCount: parsePositiveInteger(process.env.IMAGE_COUNT ?? "10", "IMAGE_COUNT"),
    jpegQuality: parsePositiveInteger(process.env.JPEG_QUALITY ?? "90", "JPEG_QUALITY"),
    cacheControl: process.env.RESPONSE_CACHE_CONTROL ?? "public, max-age=31536000, s-maxage=31536000"
  };
}

async function getRandomSourceImage(config) {
  const imageNumber = crypto.randomInt(1, config.imageCount + 1);
  const key = buildImageKey(imageNumber);
  let response;

  try {
    response = await s3.send(
      new GetObjectCommand({
        Bucket: config.imageBucket,
        Key: key
      })
    );
  } catch (error) {
    error.selectedKey = key;
    throw error;
  }

  if (!response.Body) {
    throw new Error(`S3 object body missing for key ${key}.`);
  }

  const imageBytes = await response.Body.transformToByteArray();
  return {
    key,
    buffer: Buffer.from(imageBytes)
  };
}

function textResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Access-Control-Allow-Origin": "*"
    },
    body
  };
}

exports.handler = async (event) => {
  const rawPath = event?.rawPath ?? event?.requestContext?.http?.path ?? event?.path ?? "/";

  let request;
  try {
    request = parseRequestPath(rawPath);
  } catch (error) {
    return textResponse(
      400,
      `${error.message}. Supported format: /img/{width}/{height}`
    );
  }

  if (request.specialHandler) {
    return textResponse(501, `Handler '${request.specialHandler}' is not implemented.`);
  }

  let config;
  try {
    config = getConfig();
  } catch (error) {
    console.error("Failed to load config", error);
    return textResponse(500, "Application configuration is invalid.");
  }

  try {
    const sourceImage = await getRandomSourceImage(config);
    const outputImage = await sharp(sourceImage.buffer)
      .rotate()
      .resize(request.width, request.height, { fit: "cover", position: "centre" })
      .jpeg({ quality: config.jpegQuality, mozjpeg: true })
      .toBuffer();

    return {
      statusCode: 200,
      headers: {
        "Content-Type": "image/jpeg",
        "Cache-Control": config.cacheControl,
        "Access-Control-Allow-Origin": "*"
      },
      isBase64Encoded: true,
      body: outputImage.toString("base64")
    };
  } catch (error) {
    console.error("Failed to generate placeholder image", {
      message: error.message,
      stack: error.stack,
      selectedKey: error.selectedKey,
      rawPath
    });

    return textResponse(500, "Failed to generate image.");
  }
};

exports.parseRequestPath = parseRequestPath;
exports.buildImageKey = buildImageKey;
