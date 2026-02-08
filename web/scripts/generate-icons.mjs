import sharp from 'sharp';
import { readFileSync, mkdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..');
const publicDir = join(projectRoot, 'public');
const iosAppIconDir = join(projectRoot, '..', 'ios', 'PlanToMeet', 'Images.xcassets', 'AppIcon.appiconset');
const iosMessageIconDir = join(projectRoot, '..', 'ios', 'PlanToMeetMessages', 'Assets.xcassets', 'iMessage App Icon.stickersiconset');
const baseIconPath = join(projectRoot, '..', 'ios', 'app-icon.png');

// Read the base icon PNG
const baseIconBuffer = readFileSync(baseIconPath);

async function generateIcon(outputPath, width, height = width) {
  await sharp(baseIconBuffer)
    .resize(width, height, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toFile(outputPath);
  console.log(`Generated: ${outputPath} (${width}x${height})`);
}

async function generateOGImage() {
  // Create OG image with text overlay
  const ogWidth = 1200;
  const ogHeight = 630;

  // Create gradient background
  const background = await sharp({
    create: {
      width: ogWidth,
      height: ogHeight,
      channels: 4,
      background: { r: 9, g: 9, b: 11, alpha: 1 }
    }
  })
    .composite([
      {
        input: Buffer.from(`
          <svg width="${ogWidth}" height="${ogHeight}">
            <defs>
              <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" style="stop-color:rgba(59,130,246,0.3)"/>
                <stop offset="100%" style="stop-color:rgba(139,92,246,0.3)"/>
              </linearGradient>
            </defs>
            <rect width="${ogWidth}" height="${ogHeight}" fill="url(#grad)"/>
          </svg>
        `),
        top: 0,
        left: 0,
      }
    ])
    .png()
    .toBuffer();

  // Create icon for OG image (smaller)
  const iconSize = 200;
  const iconBuffer = await sharp(baseIconBuffer)
    .resize(iconSize, iconSize)
    .png()
    .toBuffer();

  // Create text as SVG
  const textSvg = Buffer.from(`
    <svg width="${ogWidth}" height="${ogHeight}">
      <style>
        .title { fill: white; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif; font-size: 72px; font-weight: 700; }
        .subtitle { fill: #a1a1aa; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif; font-size: 32px; font-weight: 400; }
      </style>
      <text x="600" y="280" text-anchor="middle" class="title">PlanToMeet</text>
      <text x="600" y="420" text-anchor="middle" class="subtitle">Find the perfect time to meet</text>
    </svg>
  `);

  // Composite everything
  await sharp(background)
    .composite([
      {
        input: iconBuffer,
        top: 340,
        left: (ogWidth - iconSize) / 2,
      },
      {
        input: textSvg,
        top: 0,
        left: 0,
      }
    ])
    .png()
    .toFile(join(publicDir, 'og-image.png'));

  console.log('Generated: og-image.png (1200x630)');
}

async function main() {
  console.log('Generating icons...\n');

  // PWA icons
  await generateIcon(join(publicDir, 'icon-192.png'), 192);
  await generateIcon(join(publicDir, 'icon-512.png'), 512);
  await generateIcon(join(publicDir, 'apple-touch-icon.png'), 180);

  // iOS App Icon (1024x1024)
  if (existsSync(iosAppIconDir)) {
    await generateIcon(join(iosAppIconDir, 'App-Icon-1024x1024@1x.png'), 1024);
  }

  // iMessage App Icons
  if (existsSync(iosMessageIconDir)) {
    // iPhone icons
    await generateIcon(join(iosMessageIconDir, 'icon-29@2x.png'), 58);
    await generateIcon(join(iosMessageIconDir, 'icon-29@3x.png'), 87);
    await generateIcon(join(iosMessageIconDir, 'icon-60x45@2x.png'), 120, 90);
    await generateIcon(join(iosMessageIconDir, 'icon-60x45@3x.png'), 180, 135);

    // iPad icons
    await generateIcon(join(iosMessageIconDir, 'icon-29-ipad@2x.png'), 58);
    await generateIcon(join(iosMessageIconDir, 'icon-67x50@2x.png'), 134, 100);
    await generateIcon(join(iosMessageIconDir, 'icon-74x55@2x.png'), 148, 110);

    // Marketing icon
    await generateIcon(join(iosMessageIconDir, 'icon-1024x1024.png'), 1024);
    await generateIcon(join(iosMessageIconDir, 'icon-1024x768.png'), 1024, 768);

    // Universal iOS icons
    await generateIcon(join(iosMessageIconDir, 'icon-27x20@2x.png'), 54, 40);
    await generateIcon(join(iosMessageIconDir, 'icon-27x20@3x.png'), 81, 60);
    await generateIcon(join(iosMessageIconDir, 'icon-32x24@2x.png'), 64, 48);
    await generateIcon(join(iosMessageIconDir, 'icon-32x24@3x.png'), 96, 72);
  }

  // OG Image
  await generateOGImage();

  console.log('\nDone!');
}

main().catch(console.error);
