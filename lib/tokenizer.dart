import 'package:tex_to_excel/char_reader.dart';

class Tokenizer {
	List<TokenData> tokenized = [];
	final String input;
	late CharReader reader;
	int readIndex = 0;
	var operators = <String>[];
	Tokenizer(this.input) {
		reader = CharReader(this.input);
		operators.addAll(anonymousOperators);
		operators.sort();
		operators = operators.reversed.toList();
		tokenize();
	}

	List<String> getVariables() {
		var variables = <String>[];
		tokenized.forEach((token) {
			if(token.kind == "CharacterLiteral") {
				if(!variables.contains(token.raw)) {
					variables.add(token.raw);
				}
			}
		});
		return variables;
	}

	void tokenize() {
		var res = <TokenData>[];
		mainLoop:
		while(true) {
			var next = reader.getNextChar();
			if(next == CharReader.EOF) break;
			if(next == CharReader.LINE_TERMINATOR) {
				continue;
			}
			if(next == " ") continue;
			if(next.startsWith(RegExp("[0-9]"))) {
				var d = reader.readNumber();
				if(d != null) {
					res.add(TokenData(
						d, "NumberLiteral"
					));
				}
				continue;
			}
			for(var op in anonymousOperators) {
				if(reader.prefixMatch(op)) {
					res.add(TokenData(op, op));
					reader.index += op.length - 1;
					continue mainLoop;
				}
			}
			if(next == "\\") {
				var name = reader.readFuncName();
				if(name == "\\frac"
				  || name == "\\sqrt"
				  || name == "\\log") {
					res.add(TokenData(name!, name));
				}
				else if(name == "\\pi") {
					res.add(TokenData(name!, "F0Name"));
				}
				else if(name != null) {
					res.add(TokenData(name, "F1Name"));
				}
				else {
					throw Exception("unknown function");
				}
				continue;
			}
			var c = reader.readChar();
			if(c != null) {
				res.add(TokenData(c, "CharacterLiteral"));
				continue;
			}
			throw Exception("unknown character $next");
		}

		res.add(TokenData("\$", "\$"));
		readIndex = 0;
		tokenized = res;
	}
}

class TokenData {
	final String raw;
	final String kind;
	TokenData(this.raw, this.kind);
}

List<String> anonymousOperators = [
	"+", "-", "\\cdot", "!", "^", "_",
	"(", ")", "\\left|", "\\right|", "\\left(", "\\right)", "{", "}", "[", "]"
];
List<String> primitiveFuncNames = [
	"\\frac", "\\sqrt", "\\log"
];
