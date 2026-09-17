"""仅用于人工原生预览的本机固定响应，不调用模型，不记录请求正文或密钥。"""
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path('/tmp/moepeek-smart-native-preview')
ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)


def entry(word, phonetic, meaning, usage=None):
    return {
        'word': word, 'phonetic': phonetic, 'usage': usage,
        'meanings': [{'partOfSpeech': '名词' if word != 'resilient' else '形容词', 'definition': meaning}],
        'examples': [
            {'sentence': f'We value {word}.', 'translation': f'我们重视{meaning}。'},
            {'sentence': f'This example illustrates {word}.', 'translation': f'这个例子说明了{meaning}。'},
            {'sentence': f'They talked about {word}.', 'translation': f'他们讨论了{meaning}。'},
        ]
    }


class Handler(BaseHTTPRequestHandler):
    failures = 0

    def log_message(self, *args):
        pass

    def do_POST(self):
        if self.headers.get('Authorization') != 'Bearer preview-fixture':
            self.send_error(403)
            return
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        messages = body['messages']
        text = messages[-1]['content'].strip()
        parsing = 'You are an English language tutor.' in messages[0]['content']
        kind = 'parsing' if parsing else 'smart'
        allowed = {'resilient', '坚韧', "She don't understood the issue very well yesterday.", '你能解释一下为什么这个方案更可靠吗？', 'longword', 'retry', 'slow'}
        if text not in allowed:
            self.send_error(400, 'Use a preview fixture')
            return
        print(json.dumps({'stage': kind, 'fixture': text}, ensure_ascii=False), flush=True)
        if text == 'retry' and Handler.failures == 0:
            Handler.failures += 1
            self.send_error(503, 'Preview failure, submit again')
            return
        if text == 'slow':
            time.sleep(5)
        if parsing:
            if text.startswith('She'):
                result = {'mode': 'check', 'items': [{'wrong': "don't understood", 'right': "didn't understand", 'reason': "yesterday 表示过去时间，didn't 后接动词原形。"}], 'rephrase': None}
            else:
                result = {'mode': 'tutor', 'sentence': 'Could you explain why this approach is more reliable?', 'words': [{'word': 'approach', 'note': '解决问题的方法或思路。'}, {'word': 'reliable', 'note': '可靠的，强调稳定获得预期结果。'}], 'grammar': [{'structure': 'Could you + 动词原形', 'note': '委婉地提出请求。'}, {'structure': 'why 引导的宾语从句', 'note': '使用陈述语序 this approach is。'}]}
        elif text == '坚韧':
            result = {'mode': 'chineseWord', 'candidates': [entry('persistence', '/pərˈsɪstəns/', '坚持不懈', '强调持续努力。'), entry('tenacity', '/təˈnæsəti/', '坚韧', '更突出不轻易放弃的意志。')]}
        elif text.startswith('She'):
            result = {'mode': 'englishSentence', 'translation': '她昨天不太了解这个问题。'}
        elif text.startswith('你能'):
            result = {'mode': 'chineseSentence'}
        else:
            value = entry('resilient', '/rɪˈzɪliənt/', '有韧性的；适应力强的')
            value['examples'] = [
                {'sentence': 'Children can be remarkably resilient.', 'translation': '孩子们的适应能力有时强得惊人。'},
                {'sentence': 'We need a more resilient system.', 'translation': '我们需要一个恢复能力更强的系统。'},
                {'sentence': 'She remained resilient in the face of setbacks.', 'translation': '面对挫折，她依然坚韧。'},
            ]
            if text == 'longword':
                value['meanings'] = [{'partOfSpeech': '形容词', 'definition': f'第 {i+1} 条本地预览释义，用于检查长内容滚动及文字选择。'} for i in range(24)]
            result = {'mode': 'englishWord', 'entry': value}
        content = json.dumps(result, ensure_ascii=False)
        payload = json.dumps({'choices': [{'delta': {'content': content}}]}, ensure_ascii=False)
        response = f'data: {payload}\n\ndata: [DONE]\n\n'.encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Content-Length', str(len(response)))
        self.end_headers()
        try:
            self.wfile.write(response)
        except (BrokenPipeError, ConnectionResetError):
            print('预览请求已取消', flush=True)


server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
(ROOT / 'port').write_text(str(server.server_port))
print(f'本地预览端口 {server.server_port}', flush=True)
server.serve_forever()
