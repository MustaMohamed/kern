// Command-line flags for the eval runners (Task 17a, G4). Each runner names its flags in a table, and any
// other word is a usage error before anything runs: behave, h2h and kernel-adherence once read only
// `--name value` and ignored the rest, so --dryrun, --case=x or a trailing --case ran every case for real.

export class UsageError extends Error {}

// parseArgs(args, flags): { <key>: value } for each flag given, and nothing for a flag left out. flags maps
// each flag to { key, value, choices, list, noun }:
// - no value: a switch, true when given;
// - value 'count': a whole number of at least 1, written without a sign or a leading zero;
// - any other value (it names what the flag needs, for the message): a word, which must be one of choices
//   when they are given; with list, a comma-separated list whose every item is one of list, as an array.
// noun names one choice in the message. An unknown word (a typo, --case=x, a bare word), a flag given
// twice, and a missing value or one that is itself a flag are each a UsageError.
export function parseArgs(args, flags) {
  const out = {};
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    const f = Object.hasOwn(flags, a) ? flags[a] : null;
    if (!f) throw new UsageError(`unknown argument ${a}`);
    if (Object.hasOwn(out, f.key)) throw new UsageError(`${a} given twice`);
    if (!f.value) { out[f.key] = true; continue; }
    const v = args[i + 1];
    const needs = f.value === 'count' ? 'a whole number of at least 1' : f.value;
    if (v === undefined || v.startsWith('--')) throw new UsageError(`${a} needs ${needs}`);
    i += 1;
    const known = (x, from) => {
      if (!from.includes(x)) throw new UsageError(`no ${f.noun || 'value'} named ${x}; ${f.noun || 'value'}s: ${from.join(', ')}`);
      return x;
    };
    if (f.value === 'count') {
      if (!/^[1-9]\d*$/.test(v)) throw new UsageError(`${a} needs ${needs}, not ${v}`);
      out[f.key] = Number(v);
    } else if (f.list) out[f.key] = v.split(',').map((x) => known(x, f.list));
    else out[f.key] = f.choices ? known(v, f.choices) : v;
  }
  return out;
}
