import inquirer from 'inquirer';
import { execSync } from 'child_process';

async function run() {
  const { action } = await inquirer.prompt([
    {
      type: 'list',
      name: 'action',
      message: 'RBT Tunnel Orchestrator Menu',
      choices: [
        { name: '1. Add Tunnel', value: 'add' },
        { name: '2. Apply Config', value: 'apply' },
        { name: '3. Stream Logs', value: 'logs' },
        { name: '4. Get Stats', value: 'stats' },
        { name: '5. Exit', value: 'exit' },
      ],
    },
  ]);

  switch (action) {
    case 'add':
      const answers = await inquirer.prompt([
        { type: 'input', name: 'name', message: 'Tunnel Name:' },
        { type: 'input', name: 'listen', message: 'Listen Address (e.g., 0.0.0.0:8080):' },
        { type: 'input', name: 'target', message: 'Target Address (e.g., 127.0.0.1:3000):' },
        { type: 'list', name: 'proto', choices: ['tcp', 'udp'], message: 'Protocol:' },
      ]);
      execSync(`rbt link-add --name ${answers.name} --listen ${answers.listen} --target ${answers.target} --proto ${answers.proto}`, { stdio: 'inherit' });
      break;
    case 'apply':
      execSync('rbt apply', { stdio: 'inherit' });
      break;
    case 'logs':
      execSync('rbt logs -f', { stdio: 'inherit' });
      break;
    case 'stats':
      execSync('rbt stats --json', { stdio: 'inherit' });
      break;
    case 'exit':
      process.exit(0);
  }
}

run();
