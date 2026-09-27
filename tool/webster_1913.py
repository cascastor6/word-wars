"""Parses Project Gutenberg's Webster's Unabridged Dictionary (1913) into
{WORD: [(type, definition), ...]} in dictionary order."""
import re

POS = [  # abbreviation after the headword -> type, checked in order
    (r'definite article|indefinite article|\barticle\b', 'article'),
    (r'\bv\. ?t\.|\bv\. ?i\.|\bv\.|\bimp\.|\bp\. ?p\.|\bp\. ?pr\.|\bauxiliary\b', 'verb'),
    (r'\bprep\.', 'preposition'), (r'\bconj\.', 'conjunction'),
    (r'\bpron\.', 'pronoun'), (r'\binterj\.', 'interjection'),
    (r'\badv\.', 'adverb'), (r'\ba\.', 'adjective'), (r'\bn\.', 'noun'),
]
HEAD = re.compile(r"^[A-Z][A-Z' -]*(; [A-Z][A-Z' -]*)*$")
DOMAIN = re.compile(r'^(\([A-Z][^)]{0,30}\)\s*)+')
NUM = re.compile(r'^(\d+\.|\([a-z]\))\s*')

def clean(p):
    p = NUM.sub('', p.replace('Defn:', '').strip())
    p = DOMAIN.sub('', p).strip()
    p = re.sub(r'\[[^\]]*\]', '', p)            # [Obs.], [Colloq.] and etymology notes
    p = re.split(r'; as,|; --| "| --', p)[0]    # drop usage examples and sub-entries
    p = re.sub(r'\s+', ' ', p).strip(' ;,')
    if len(p) > 220:                            # keep the first sentence or two
        cuts = [m.start() for m in re.finditer(r'\w{3,}\. ', p[:222])]
        cut = cuts[-1] + len(re.match(r'\w+', p[cuts[-1]:]).group()) if cuts else -1
        p = p[:cut + 1] if cut > 40 else p[:217].rsplit(' ', 1)[0] + '...'
    p = p.rstrip()
    # strip trailing author citations like "Shak." or "Milton."
    p = re.sub(r'(\. [A-Z][A-Za-z.]*( [A-Z][A-Za-z.]*)?\.?)+$', '.', p)
    return p[:1].upper() + p[1:] if p else ''

def parse(path):
    lines = open(path, encoding='utf-8').read().replace('\r', '').split('\n')
    start = next(i for i, l in enumerate(lines) if l.startswith('*** START'))
    end = next(i for i, l in enumerate(lines) if l.startswith('*** END'))
    out = {}
    i = start + 1
    while i < end:
        if not (HEAD.match(lines[i]) and i + 1 < end and lines[i + 1][:1].isupper()):
            i += 1
            continue
        heads = [h.strip() for h in lines[i].split(';')]
        j = i + 1
        while j < end and not (HEAD.match(lines[j]) and j + 1 < end and lines[j + 1][:1].isupper()
                               and lines[j - 1] == ''):
            j += 1
        body = lines[i + 1:j]
        paras = [' '.join(x.split('\n')) for x in '\n'.join(body).split('\n\n') if x.strip()]
        header = paras[0] if paras else ''
        pre = re.split(r'Etym:|\[', header)[0]
        typ = next((t for pat, t in POS if re.search(pat, pre)), None)
        defn = ''
        for p in paras[1:] if len(paras) > 1 else paras:
            if p.startswith(('Note:', 'Syn.', 'Etym')): continue
            if p.startswith('Defn:') or NUM.match(p):
                defn = clean(p)
                if defn: break
        if defn and typ:
            obs = '[Obs.]' in ' '.join(paras[:3])
            for h in heads:
                if re.fullmatch(r'[A-Z]+', h):
                    out.setdefault(h, []).append((typ, defn, obs))
        i = j
    return out

def best(senses):
    """First sense that isn't obsolete or a bare cross-reference."""
    for t, d, obs in senses:
        if not obs and not d.startswith('See '):
            return t, d
    return senses[0][:2]

def resolve(w, dic, seen=()):
    """Best sense for [w], following "See X." cross-references."""
    t, d = best(dic[w])
    m = re.fullmatch(r'See ([A-Z][a-z]+)\.?', d)
    if m and m.group(1).upper() in dic and m.group(1).upper() not in seen:
        return resolve(m.group(1).upper(), dic, seen + (w,))
    return t, d
