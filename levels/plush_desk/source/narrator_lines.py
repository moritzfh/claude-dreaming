"""Lists every narrator line of "First Stitches" with the file name its
recorded voice is looked up under (story/narrator.gd, voice_key()), and
writes source/narrator_lines.md (a script for the voice) and
source/narrator_lines.tsv (key<TAB>text to speak).

Run from the repo root:  python3 levels/plush_desk/source/narrator_lines.py

Voice files go to levels/plush_desk/audio/narrator/<key>.ogg (.wav and .mp3
work too). Lines with the player's name ("%s") are recorded without it, the
subtitle still shows the name.
"""
import os, re, glob

HERE = os.path.dirname(os.path.abspath(__file__))
STORY = os.path.join(HERE, '..', 'story')
VOICE = os.path.join(HERE, '..', 'audio', 'narrator')
CALL = re.compile(r'\b(narrate_at|narrate|_say|_line)\(')
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')

# where the lines are, in the order they come up
ORDER = ['sec_arrival', 'sec_meadow', 'sec_clouds', 'sec_patches', 'sec_machine', 'sec_choice',
         'sec_tower', 'sec_finale']
PLACE = {'sec_arrival': 'The guestbook', 'sec_meadow': 'Felt meadow', 'sec_clouds': 'Cotton clouds',
         'sec_patches': 'Mend it!', 'sec_machine': 'The Stitch-O-Matic', 'sec_choice': 'Your choice',
         'sec_tower': 'The yarn tower', 'sec_finale': 'The theatre and the quilt'}


def key_of(text):
    s = text.lower().replace("'", '').replace('’', '')
    return '_'.join(re.findall(r'[a-z0-9]+', s)[:6])


def calls(src):
    """the argument text of every narrator call (parentheses balanced, strings respected)"""
    for m in CALL.finditer(src):
        line_start = src.rfind('\n', 0, m.start()) + 1
        if src[line_start:m.start()].lstrip().startswith(('func ', '#')):
            continue
        i, depth, ins = m.end(), 1, False
        while i < len(src) and depth:
            c = src[i]
            if ins:
                if c == '\\':
                    i += 1
                elif c == '"':
                    ins = False
            elif c == '"':
                ins = True
            elif c in '([{':
                depth += 1
            elif c in ')]}':
                depth -= 1
            i += 1
        yield src[m.end():i - 1]


def lines():
    out, seen = [], set()
    files = sorted(glob.glob(os.path.join(STORY, 'sec_*.gd')),
                   key=lambda f: ORDER.index(os.path.basename(f)[:-3]) if os.path.basename(f)[:-3] in ORDER else 99)
    for f in files:
        sec = os.path.basename(f)[:-3]
        for args in calls(open(f, encoding='utf-8').read()):
            for t in STR.findall(args):
                t = t.encode().decode('unicode_escape') if '\\' in t else t
                if ' ' not in t or t in seen:
                    continue            # keys like "medal"
                seen.add(t)
                out.append((sec, key_of(t), t))
    return out


def spoken(t):
    """what the voice says: the player's name is left out"""
    return t.replace(', %s,', '').replace(', %s.', '.')


if __name__ == '__main__':
    L = lines()
    keys = [k for _, k, _ in L]
    dup = {k for k in keys if keys.count(k) > 1}
    assert not dup, 'two lines share a key: %s' % dup
    have = {os.path.splitext(f)[0] for f in os.listdir(VOICE)} if os.path.isdir(VOICE) else set()
    md = ['# First Stitches – the narrator\'s lines', '',
          'One file per line in `levels/plush_desk/audio/narrator/`, named after the key '
          '(`<key>.ogg`, `.wav` or `.mp3`). Mono is fine, 44.1 or 48 kHz, a little silence '
          '(about 0.1 s) at the start and end, no music or effects underneath. '
          'Lines marked *(name)* show the player\'s name in the subtitle: record them without it.', '',
          'The voice: a warm, gentle storyteller reading a bedtime story to a child, a little '
          'dry humour, never shouting. Not an imitation of a real person.', '']
    sec_prev, n = None, 0
    for sec, k, t in L:
        if sec != sec_prev:
            md += ['', '## ' + PLACE.get(sec, sec), '', '| # | file | line |', '|---|---|---|']
            sec_prev = sec
        n += 1
        mark = ' *(name)*' if '%s' in t else ''
        done = ' ✓' if k in have else ''
        md.append('| %d | `%s`%s | %s%s |' % (n, k, done, spoken(t), mark))
    open(os.path.join(HERE, 'narrator_lines.md'), 'w', encoding='utf-8').write('\n'.join(md) + '\n')
    open(os.path.join(HERE, 'narrator_lines.tsv'), 'w', encoding='utf-8').write(
        ''.join('%s\t%s\n' % (k, spoken(t)) for _, k, t in L))
    print('%d lines, %d recorded' % (len(L), len(have & set(keys))))
