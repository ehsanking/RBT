import fs from 'fs';
import path from 'path';

const envPath = path.join(process.cwd(), '.env');
let envContent = '';

if (fs.existsSync(envPath)) {
  envContent = fs.readFileSync(envPath, 'utf8');
}

const key = 'VITE_ENABLE_HCAPTCHA';
const regex = new RegExp(`^${key}=(.*)$`, 'm');
const match = envContent.match(regex);

let newContent;
if (match) {
  const newValue = match[1] === 'true' ? 'false' : 'true';
  newContent = envContent.replace(regex, `${key}=${newValue}`);
  console.log(`hCaptcha is now ${newValue}`);
} else {
  newContent = envContent + `\n${key}=true\n`;
  console.log(`hCaptcha is now true`);
}

fs.writeFileSync(envPath, newContent);
