import readline from 'readline';
import fs from 'fs';
import path from 'path';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const question = (query: string): Promise<string> => {
  return new Promise((resolve) => rl.question(query, resolve));
};

async function setup() {
  console.log('\n--- RBT Dashboard hCaptcha Setup ---\n');
  
  const enable = await question('Do you want to enable hCaptcha for the login page? (y/n): ');
  
  if (enable.toLowerCase() === 'y') {
    const siteKey = await question('Enter your hCaptcha Site Key: ');
    const secretKey = await question('Enter your hCaptcha Secret Key: ');
    
    const envPath = path.join(process.cwd(), '.env');
    let envContent = '';
    
    if (fs.existsSync(envPath)) {
      envContent = fs.readFileSync(envPath, 'utf-8');
    }
    
    // Remove existing keys if any
    const lines = envContent.split('\n').filter(line => 
      !line.startsWith('VITE_HCAPTCHA_SITE_KEY=') && 
      !line.startsWith('HCAPTCHA_SECRET_KEY=') &&
      line.trim() !== ''
    );
    
    lines.push(`VITE_HCAPTCHA_SITE_KEY=${siteKey}`);
    lines.push(`HCAPTCHA_SECRET_KEY=${secretKey}`);
    
    fs.writeFileSync(envPath, lines.join('\n') + '\n');
    
    console.log('\n✅ hCaptcha configured successfully in .env file.');
    console.log('Please restart the dashboard to apply changes.');
  } else {
    console.log('\nℹ️ hCaptcha setup skipped.');
  }
  
  rl.close();
}

setup().catch(err => {
  console.error('Setup failed:', err);
  rl.close();
});
