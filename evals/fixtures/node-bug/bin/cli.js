#!/usr/bin/env node
import { writeFileSync } from 'node:fs';
import { sum } from '../src/sum.js';

const [a, b] = process.argv.slice(2).map(Number);
writeFileSync('total.txt', `${sum(a, b)}\n`);
