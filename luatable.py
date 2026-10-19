# Minimaler Parser/Serializer für DCS-Lua-Tabellen (mission/dictionary-Format)
import re
class P:
    def __init__(s, t): s.t, s.i = t, 0
    def ws(s):
        while True:
            m = re.compile(r'\s+').match(s.t, s.i)
            if m: s.i = m.end()
            if s.t.startswith('--', s.i):
                j = s.t.find('\n', s.i); s.i = len(s.t) if j < 0 else j
                continue
            break
    def val(s):
        s.ws(); c = s.t[s.i]
        if c == '{': return s.table()
        if c == '"': return s.string()
        m = re.compile(r'-?\d+(\.\d+)?([eE][-+]?\d+)?').match(s.t, s.i)
        if m:
            s.i = m.end(); txt = m.group(0)
            return float(txt) if ('.' in txt or 'e' in txt or 'E' in txt) else int(txt)
        for w, v in (('true', True), ('false', False), ('nil', None)):
            if s.t.startswith(w, s.i): s.i += len(w); return v
        raise ValueError("unerwartet bei %d: %r" % (s.i, s.t[s.i:s.i+30]))
    def string(s):
        s.i += 1; out = []
        while True:
            c = s.t[s.i]
            if c == '\\':
                n = s.t[s.i+1]
                out.append({'n': '\n', 't': '\t', '"': '"', '\\': '\\', '\n': '\n'}.get(n, n)); s.i += 2
            elif c == '"': s.i += 1; return ''.join(out)
            else: out.append(c); s.i += 1
    def table(s):
        s.i += 1; d = {}; arr = 1
        while True:
            s.ws()
            if s.t[s.i] == '}': s.i += 1; return d
            if s.t[s.i] == '[':
                s.i += 1; k = s.val(); s.ws(); assert s.t[s.i] == ']'; s.i += 1
                s.ws(); assert s.t[s.i] == '='; s.i += 1
                d[k] = s.val()
            else:
                d[arr] = s.val(); arr += 1
            s.ws()
            if s.t[s.i] in ',;': s.i += 1

def parse(text):
    p = P(text); p.ws()
    m = re.compile(r'[A-Za-z_]\w*').match(text, p.i); p.i = m.end(); p.ws()
    assert text[p.i] == '='; p.i += 1
    return m.group(0), p.val()

def ser(v, ind=0):
    tab = '\t' * ind
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, int): return str(v)
    if isinstance(v, float): return repr(v)
    if isinstance(v, str):
        return '"' + v.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\\n') + '"'
    if isinstance(v, dict):
        if not v: return '{}'
        lines = ['', tab + '{']
        keys = sorted(v.keys(), key=lambda k: (0, k) if isinstance(k, int) else (1, str(k)))
        for k in keys:
            ks = '[%d]' % k if isinstance(k, int) else '["%s"]' % k
            lines.append('%s\t%s = %s,' % (tab, ks, ser(v[k], ind + 1)))
        lines.append(tab + '}')
        return '\n'.join(lines)
    raise TypeError(type(v))

def dump(name, v):
    return '%s = %s -- end of %s\n' % (name, ser(v, 0).lstrip('\n'), name)
