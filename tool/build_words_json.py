import json, sys
# Builds assets/words.json from assets/words.txt, Princeton WordNet 3.1 and
# Project Gutenberg's Webster's Unabridged Dictionary (1913, ebook #29765).
# WordNet is tried first; Webster fills in words WordNet doesn't know.
# Words still without a definition are left out.
# Usage (from the project root):
#   python3 tool/build_words_json.py <dir containing WordNet dict/> <pg29765.txt>
import os
sys.path.insert(0, os.path.dirname(__file__))
from webster_1913 import parse, resolve
D = sys.argv[1] + '/dict/'
POS = {'n': 'noun', 'v': 'verb', 'a': 'adjective', 'r': 'adverb'}
FILES = {'n': 'noun', 'v': 'verb', 'a': 'adj', 'r': 'adv'}

# lemma -> pos -> (first synset offset, tagged sense count)
index = {}
for p, f in FILES.items():
    for line in open(D + 'index.' + f, encoding='latin-1'):
        if line.startswith(' '): continue
        t = line.split()
        lemma, n_ptr = t[0], int(t[3])
        cnt = int(t[5 + n_ptr])
        offset = t[6 + n_ptr]
        index.setdefault(lemma, {})[p] = (offset, cnt)

def gloss(p, offset):
    with open(D + 'data.' + FILES[p], 'rb') as fh:
        fh.seek(int(offset))
        g = fh.readline().decode('latin-1').split(' | ', 1)[1].strip()
    # drop quoted usage examples, keep the definition
    g = g.split('; "')[0].split(' "')[0].strip().rstrip(';').strip()
    return g[:1].upper() + g[1:] if g else g

exc = {p: {} for p in FILES}
for p, f in FILES.items():
    for line in open(D + f + '.exc', encoding='latin-1'):
        t = line.split()
        exc[p].setdefault(t[0], t[1])

RULES = {
    'n': [('ses', 's', 'Plural of'), ('xes', 'x', 'Plural of'), ('zes', 'z', 'Plural of'),
          ('ches', 'ch', 'Plural of'), ('shes', 'sh', 'Plural of'), ('men', 'man', 'Plural of'),
          ('ies', 'y', 'Plural of'), ('s', '', 'Plural of')],
    'v': [('ies', 'y', 'Present tense of'), ('es', 'e', 'Present tense of'), ('es', '', 'Present tense of'),
          ('s', '', 'Present tense of'), ('ied', 'y', 'Past tense of'), ('ed', 'e', 'Past tense of'),
          ('ed', '', 'Past tense of'), ('ing', 'e', 'Present participle of'), ('ing', '', 'Present participle of')],
    'a': [('er', '', 'Comparative of'), ('est', '', 'Superlative of'), ('er', 'e', 'Comparative of'),
          ('est', 'e', 'Superlative of'), ('ier', 'y', 'Comparative of'), ('iest', 'y', 'Superlative of')],
    'r': [],
}
EXC_LABEL = {'n': 'Plural of', 'v': 'Form of', 'a': 'Form of', 'r': 'Form of'}

def best(lemma):
    """Most-used part of speech for a lemma: (pos, offset)."""
    order = 'nvar'
    p = max(index[lemma], key=lambda p: (index[lemma][p][1], -order.index(p)))
    return p, index[lemma][p][0]

def base_forms(w):
    """Candidate (pos, base, label) for an inflected word, in preference order."""
    out = []
    for p in 'nva':
        b = exc[p].get(w)
        if b and b in index and p in index[b]:
            out.append((p, b, EXC_LABEL[p]))
    for p in 'nva':
        for suf, rep, label in RULES[p]:
            if w.endswith(suf) and len(w) > len(suf):
                b = w[:-len(suf)] + rep
                if b in index and p in index[b]:
                    out.append((p, b, label))
                # doubled consonant: stopped, running, bigger
                s = w[:-len(suf)]
                if not rep and len(s) > 2 and s[-1] == s[-2] and s[-1] not in 'aeiou':
                    b = s[:-1]
                    if b in index and p in index[b]:
                        out.append((p, b, label))
    return out

words = [w.strip() for w in open('assets/words.txt') if w.strip()]
defs = {}  # WORD -> (type, definition, how)
for W in words:
    w = W.lower()
    if w in index:
        p, off = best(w)
        defs[W] = (POS[p], gloss(p, off), 'wordnet')

web = parse(sys.argv[2])
for W in words:
    if W not in defs and W in web:
        t, d = resolve(W, web)
        defs[W] = (t, d, 'webster')

# Plurals, tenses and comparatives of words defined above.
WANT = {'Plural of': 'noun', 'Present tense of': 'verb', 'Past tense of': 'verb',
        'Present participle of': 'verb', 'Comparative of': 'adjective',
        'Superlative of': 'adjective'}
for W in words:
    if W in defs: continue
    w = W.lower()
    for p, b, label in base_forms(w):  # WordNet forms first
        defs[W] = (POS[p], f"{label} {b}: {gloss(p, index[b][p][0])}", 'form')
        break
    else:
        for p in 'nva':
            for suf, rep, label in RULES[p]:
                if not w.endswith(suf) or len(w) <= len(suf) + 1: continue
                stem = w[:-len(suf)]
                cands = [stem + rep]
                if not rep and len(stem) > 2 and stem[-1] == stem[-2] and stem[-1] not in 'aeiou':
                    cands.append(stem[:-1])
                for b in cands:
                    B = b.upper()
                    if B in defs and defs[B][2] != 'form' and defs[B][0] == WANT[label]:
                        defs[W] = (defs[B][0], f"{label} {b}: {defs[B][1]}", 'form')
                        break
                if W in defs: break
            if W in defs: break

entries = [{'word': W, 'type': defs[W][0], 'definition': defs[W][1]} for W in words if W in defs]

with open('assets/words.json', 'w') as f:
    f.write('[\n' + ',\n'.join(json.dumps(e, ensure_ascii=False, separators=(',', ':')) for e in entries) + '\n]\n')
from collections import Counter
c = Counter(v[2] for v in defs.values())
print(f"{len(entries)} words: {c['wordnet']} WordNet, {c['webster']} Webster, {c['form']} plural/tense forms, "
      f"{len(words) - len(entries)} left out without a definition")
