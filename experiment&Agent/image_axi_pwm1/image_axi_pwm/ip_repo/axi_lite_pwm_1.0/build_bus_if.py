import re, os, sys

PKG = r'D:/FPGAproject/AnLuRun/MainProject/ip_repo/axi_lite_pwm_1.0'
REF = r'D:/exe/Anlu/TD/ip/depot/AXI_GPIO_1.0/Component.xml'

comp = open(PKG + '/Component.xml', encoding='utf-8', newline='').read()
ref = open(REF, encoding='utf-8', newline='').read()

if 'ipxact:busInterfaces' in comp:
    sys.exit('ABORT: Component.xml 已含 busInterfaces，未做任何修改')

# ---- 1. 从 TD 自带 AXI_GPIO 提取三条接口，只保留 AXI / clock / reset ----
refblk = re.search(r'<ipxact:busInterfaces>.*?</ipxact:busInterfaces>', ref, re.S).group(0)
segs = re.findall(r'<ipxact:busInterface>.*?</ipxact:busInterface>', refblk, re.S)

kept = []
for seg in segs:
    nm = re.search(r'<ipxact:name>(.*?)</ipxact:name>', seg).group(1)
    if nm == 'S_AXI_Lite':
        seg = seg.replace('>S_AXI_Lite<', '>S_AXI<')
        kept.append(('S_AXI', seg))
    elif nm in ('S_AXI_ACLK', 'S_AXI_AResetn'):
        kept.append((nm, seg))

names = [n for n, _ in kept]
if names != ['S_AXI', 'S_AXI_ACLK', 'S_AXI_AResetn']:
    sys.exit('ABORT: 提取到的接口顺序/数量异常 -> %r' % (names,))

body = ''
for _, seg in kept:
    body += '\n        ' + seg.strip()

busblk = '    <ipxact:busInterfaces>' + body + '\n    </ipxact:busInterfaces>'

# ---- 2. memoryMaps ----
regs = [
    ('ctrl',      '0x0',  'read-write', 'PWM0/1/2 enable + motor enable'),
    ('dir',       '0x4',  'read-write', 'motor0/motor1 direction'),
    ('status',    '0x8',  'read-only',  'update pending / enable / motor enable'),
    ('version',   '0xc',  'read-only',  'constant 0x00010000'),
    ('pwm0_psc',  '0x10', 'read-write', 'PWM0 prescaler'),
    ('pwm0_arr',  '0x14', 'read-write', 'PWM0 auto reload (period)'),
    ('pwm0_ccr',  '0x18', 'read-write', 'PWM0 compare (duty)'),
    ('pwm1_psc',  '0x20', 'read-write', 'PWM1 prescaler'),
    ('pwm1_arr',  '0x24', 'read-write', 'PWM1 auto reload (period)'),
    ('pwm1_ccr',  '0x28', 'read-write', 'PWM1 compare (duty)'),
    ('pwm2_psc',  '0x30', 'read-write', 'PWM2 prescaler'),
    ('pwm2_arr',  '0x34', 'read-write', 'PWM2 auto reload (period)'),
    ('pwm2_ccr',  '0x38', 'read-write', 'PWM2 compare (duty)'),
    ('update',    '0x40', 'read-write', 'write 1 to a bit to commit that channel'),
]

L = []
L.append('    <ipxact:memoryMaps>')
L.append('        <ipxact:memoryMap>')
L.append('            <ipxact:name>axi_lite_slave</ipxact:name>')
L.append('            <ipxact:displayName></ipxact:displayName>')
L.append('            <ipxact:addressBlock>')
L.append('                <ipxact:name>pwm_regs</ipxact:name>')
L.append('                <ipxact:displayName></ipxact:displayName>')
L.append('                <ipxact:baseAddress>0x00000000</ipxact:baseAddress>')
L.append('                <ipxact:range>128</ipxact:range>')
L.append('                <ipxact:width>32</ipxact:width>')
L.append('                <ipxact:usage>register</ipxact:usage>')
L.append('                <ipxact:access>read-write</ipxact:access>')
for rn, off, acc, desc in regs:
    L.append('                <ipxact:register>')
    L.append('                    <ipxact:name>%s</ipxact:name>' % rn)
    L.append('                    <ipxact:displayName></ipxact:displayName>')
    L.append('                    <ipxact:addressOffset>%s</ipxact:addressOffset>' % off)
    L.append('                    <ipxact:size>32</ipxact:size>')
    L.append('                    <ipxact:access>%s</ipxact:access>' % acc)
    L.append('                </ipxact:register>')
L.append('            </ipxact:addressBlock>')
L.append('        </ipxact:memoryMap>')
L.append('    </ipxact:memoryMaps>')
memblk = '\n'.join(L)

# ---- 3. 插入到 <ipxact:model> 之前 ----
anchor = '\n    <ipxact:model>'
if comp.count(anchor) != 1:
    sys.exit('ABORT: 找不到唯一的 <ipxact:model> 锚点')

insert = '\n' + busblk + '\n' + memblk
comp_new = comp.replace(anchor, insert + anchor, 1)

# ---- 4. 统一行尾为 CRLF ----
comp_new = comp_new.replace('\r\n', '\n').replace('\n', '\r\n')

open(PKG + '/Component.xml', 'w', encoding='utf-8', newline='').write(comp_new)
print('OK: 已写入')
print('原大小 %d -> 新大小 %d' % (len(comp), len(comp_new)))
