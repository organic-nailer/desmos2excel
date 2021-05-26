import 'dart:convert';

class CharReader {

	static final String EOF = AsciiDecoder().convert([26]);
	static final String LINE_TERMINATOR = "\n";

	final String inputStr;
	List<String> inputStrings;
	int inputIndex = 0;
	String line = "";
	int lineLength = 0;
	int index = 0;
	int lineNumber = 0;
	CharReader(this.inputStr) {
		inputStrings = inputStr.split("\n");
	}

	String getNextChar() {
		if(index + 1 < lineLength) {
			return line[++index];
		}
		if(++index == lineLength && inputStrings.length != inputIndex) {
			return LINE_TERMINATOR;
		}
		return readNextLine() ?? EOF;
	}

	String readNextLine() {
		if(inputStrings.length == inputIndex) return EOF;
		line = inputStrings[inputIndex++];
		lineNumber++;
		lineLength = line.length;
		index = -1;
		return getNextChar();
	}

	bool prefixMatch(String value) {
		if(index >= lineLength) return false;
		return line.startsWith(value, index);
	}

	var numberPattern = RegExp(r"^((0|[1-9][0-9]*)\.[0-9]*|\.[0-9]*|(0|([1-9][0-9]*)))");
	String readNumber() {
		var subStr = line.substring(index);
		var match = numberPattern.firstMatch(subStr);
		if(match == null) return null;
		var matchStr = subStr.substring(match.start, match.end);
		index += matchStr.length - 1;
		return matchStr;
	}

	var identifierPattern = RegExp(r"^\\[A-Za-z\$\_][A-Za-z\$\_]*");
	String readFuncName() {
		var subStr = line.substring(index);
		var match = identifierPattern.firstMatch(subStr);
		if(match == null) return null;
		var matchStr = subStr.substring(match.start, match.end);
		index += matchStr.length - 1;
		return matchStr;
	}

	var charPattern = RegExp(r"^[A-Za-z]");
	String readChar() {
		var subStr = line.substring(index);
		var match = charPattern.firstMatch(subStr);
		if(match == null) return null;
		var matchStr = subStr.substring(match.start, match.end);
		index += matchStr.length - 1;
		return matchStr;
	}
}