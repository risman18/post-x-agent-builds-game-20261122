#!/bin/bash
# Build the 16:9 entry video (1920x1080, 30fps) from real session artefacts:
#  A prompt card (ffmpeg drawtext)          4.0s
#  B agent working (real code + terminal stills)  3 x 2.5s
#  C real gameplay (CDP screencast frames 40-150) ~12.3s
#  D payoff freeze frame + text             2.5s
#  E press-pack 16:9 end card, code typed in  3.0s
# make.fun brand badge overlays A-D at 100%, ending where the card starts.
set -euo pipefail
cd /home/hatch/workspace/makefun/post-x-22/work
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
MONO=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf
CARD_START=26.33

# --- A: prompt card ---
ffmpeg -y -v error -f lavfi -i color=c=0x0d0d1a:s=1920x1080:d=4 -vf \
"drawtext=fontfile=$FONT:text='ONE PROMPT':fontsize=64:fontcolor=0xff5a5a:x=(w-text_w)/2:y=170,\
drawtext=fontfile=$FONT:text='a tiny browser game\:':fontsize=96:fontcolor=white:x=(w-text_w)/2:y=320,\
drawtext=fontfile=$FONT:text='dodge the falling meteors,':fontsize=96:fontcolor=white:x=(w-text_w)/2:y=450,\
drawtext=fontfile=$FONT:text='collect stars, 60 seconds':fontsize=96:fontcolor=0xffd34d:x=(w-text_w)/2:y=580,\
drawtext=fontfile=$FONT:text='My AI agent builds it. I just watch.':fontsize=46:fontcolor=0x9aa0b0:x=(w-text_w)/2:y=830" \
-c:v libx264 -pix_fmt yuv420p -r 30 seg-a.mp4

# --- B: working stills with a slow zoom ---
for s in still-code-a still-code-b still-term; do
  ffmpeg -y -v error -loop 1 -i $s.png -vf \
"zoompan=z='min(zoom+0.0004,1.06)':d=75:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1920x1080:fps=30,format=yuv420p" \
  -t 2.5 -c:v libx264 -r 30 seg-$s.mp4
done

# --- C: real gameplay, frames 40-150 of the 25s capture (~9fps source -> 30fps) ---
ffmpeg -y -v error -framerate 9 -start_number 40 -i frames2/frame-%04d.jpg \
  -vf "fps=30,format=yuv420p" -t 12.33 -c:v libx264 -r 30 seg-gameplay.mp4

# --- D: payoff freeze on the last gameplay frame ---
ffmpeg -y -v error -loop 1 -i frames2/frame-0150.jpg -vf \
"drawtext=fontfile=$FONT:text='IT WORKS.':fontsize=110:fontcolor=white:x=(w-text_w)/2:y=400:shadowcolor=black:shadowx=4:shadowy=4,\
drawtext=fontfile=$FONT:text='One prompt. One game. 60 seconds.':fontsize=56:fontcolor=0xffd34d:x=(w-text_w)/2:y=560:shadowcolor=black:shadowx=3:shadowy=3,format=yuv420p" \
  -t 2.5 -c:v libx264 -r 30 seg-payoff.mp4

# --- E: end card (press pack, as issued) with referral code typed into the field ---
# Field per manifest 16:9: code box x=432 y=694, 62px JetBrains Mono Bold / Inter Bold,
# colour #191419; cover the blinking caret with white first (manifest "cover_with").
ffmpeg -y -v error -i card-16x9.mp4 -vf \
"fps=30,drawbox=x=430:y=692:w=9:h=81:color=white:t=fill:enable='gte(t,1.5)',\
drawtext=fontfile=$MONO:text='7trfcnag':fontsize=62:fontcolor=0x191419:x=432:y=694:enable='gte(t,1.5)',format=yuv420p" \
  -c:v libx264 -r 30 seg-card.mp4

# --- concat body, then card, then badge overlay + silent audio ---
printf "file 'seg-a.mp4'\nfile 'seg-still-code-a.mp4'\nfile 'seg-still-code-b.mp4'\nfile 'seg-still-term.mp4'\nfile 'seg-gameplay.mp4'\nfile 'seg-payoff.mp4'\n" > body.txt
ffmpeg -y -v error -f concat -safe 0 -i body.txt -c:v libx264 -pix_fmt yuv420p -r 30 body.mp4
printf "file 'body.mp4'\nfile 'seg-card.mp4'\n" > all.txt
ffmpeg -y -v error -f concat -safe 0 -i all.txt -c:v libx264 -pix_fmt yuv420p -r 30 nocard-badge.mp4
ffmpeg -y -v error -i nocard-badge.mp4 -i badge-16x9.png -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
  -filter_complex "[0:v][1:v]overlay=0:0:enable='lt(t,$CARD_START)'[v]" \
  -map "[v]" -map 2:a -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -c:a aac -shortest \
  -movflags +faststart meteor-dodge-30s.mp4
ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height,codec_name,r_frame_rate -of default=nw=1 meteor-dodge-30s.mp4
ls -l meteor-dodge-30s.mp4
