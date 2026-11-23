// post-x-agent-builds-game-20261122 — entry program (Node 22, standard library only).
//
// The entry is the X post named in POST.json: this program's only job is to hand
// that file to the grader by copying it from the repository root into the output
// directory. It reads no network, no wall clock, and nothing outside the repo, so
// two runs always write the same bytes.
//
// The post itself is the entry: a short video about an AI coding agent building a
// tiny browser game ("Meteor Dodge") from one prompt, ending with make.fun's
// referral end card carrying referral code 7trfcnag. The video file sits at
// video/meteor-dodge-30s.mp4; the game it shows is game.html in this repo.
//
// Local check (the way the grader runs it, with local stand-ins for /bot and /output):
//   mkdir -p out && MAKEFUN_BOT_DIR=. MAKEFUN_OUTPUT_DIR=out node main.ts
// Afterwards out/POST.json is byte-for-byte this directory's POST.json.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const botDir = process.env.MAKEFUN_BOT_DIR ?? '/bot';
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

const post = readFileSync(join(botDir, 'POST.json'));
mkdirSync(outputDir, { recursive: true });
writeFileSync(join(outputDir, 'POST.json'), post);
// Nothing else is written: the house reads the post's counts from X itself
// and writes them to /output/post.counts.json after this program runs.
