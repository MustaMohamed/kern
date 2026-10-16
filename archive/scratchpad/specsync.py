import re, json, sys
S='/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad'
SPEC='/Users/musta/Code/projects/kern/docs/specs/2026-10-12-kern-m1-m2-skills.md'
def short(t):
    t=re.sub(r'`bash \$\{CLAUDE_PLUGIN_ROOT\}/scripts/([\w-]+)','`\\1',t)
    t=re.sub(r'`bash \$\{CLAUDE_PLUGIN_ROOT\}/skills/([\w-]+)/scripts/([\w.-]+)','`\\2',t)
    t=re.sub(r'`\$\{CLAUDE_PLUGIN_ROOT\}/skills/([\w-]+)/SKILL\.md`','`\\1`',t)
    t=re.sub(r'\$\{CLAUDE_PLUGIN_ROOT\}/scripts/([\w-]+)','\\1',t)
    t=t.replace('a visual page only when kern\'s `visual` skill is installed; otherwise chat, saying once "visual pages not installed"','page when installed (A9)')
    t=t.replace('(a visual page only when kern\'s `visual` skill is installed; otherwise say once "visual pages not installed")','(page when installed, A9)')
    return t
def new_steps(name):
    k=open(f'{S}/k2/skills/{name}/SKILL.md').read()
    i=k.index('## Steps\n'); j=k.index('\n## ',i+5)
    return k[i+len('## Steps\n'):j].strip('\n').split('\n')
def old_tags(sec):
    st=sec[sec.index('**4. Steps**'):]
    tags={}; sub=[]
    for l in st.split('\n'):
        m=re.match(r'^(\d+)\. (.*)$',l)
        if m:
            t=re.findall(r'(\[[^\]]*\])\s*$',m.group(2)); tags[int(m.group(1))]=t[0] if t else ''
        m=re.match(r'^\s+- (.*)$',l)
        if m:
            t=re.findall(r'(\[[^\]]*\])\s*$',m.group(1)); sub.append(t[0] if t else '')
    return tags, sub
def build(name, sec, extra, keep_after=None, drop_new_tail=False):
    tags,sub=old_tags(sec)
    out=['**4. Steps**']; si=0
    for l in new_steps(name):
        m=re.match(r'^(\d+)\. (.*)$',l)
        if m:
            n=int(m.group(1)); body=short(m.group(2))
            if n==0: out.append('0. Defer (A6).'); continue
            tg=tags.get(n,'')
            add=extra.get(n,'')
            if add:
                tg = (tg[:-1]+'; '+add+']') if tg else '['+add+']'
            out.append(f'{n}. {body}' + (f' {tg}' if tg else ''))
            continue
        m=re.match(r'^(\s+)- (.*)$',l)
        if m:
            tg=sub[si] if si<len(sub) else ''; si+=1
            out.append(f'{m.group(1)}- {short(m.group(2))}' + (f' {tg}' if tg and tg not in m.group(2) else ''))
            continue
        out.append(short(l))
    return '\n'.join(out).rstrip('\n')
def replace_steps(spec, cid, name, extra, tail):
    i=spec.index(f'### {cid}. `{name}`'); j=spec.index('\n### ',i+5) if '\n### ' in spec[i+5:] else len(spec)
    sec=spec[i:j]
    a=sec.index('**4. Steps**'); b=sec.index('**5. Outputs')
    newsteps=build(name, sec, extra)
    body=newsteps+'\n\n'+(tail+'\n\n' if tail else '')
    sec=sec[:a]+body+sec[b:]
    return spec[:i]+sec+spec[j:]
