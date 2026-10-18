import { existsSync, readFileSync } from 'node:fs';
import { RATES } from './defaults.js';

const FILE = '.cache/rates.json';

export function loadRates() {
  if (existsSync(FILE)) return JSON.parse(readFileSync(FILE, 'utf8'));
  return RATES;
}

export const convert = (amount, to) => Math.round(amount * loadRates().rates?.[to] * 100) / 100;
