import 'dart:collection';

import 'package:csv/csv.dart';
import 'package:tex_to_excel/tokenizer.dart';

class Parser {
	Map<String, TransitionData> transitionMap = {};
	Parser() {
		var list = const CsvToListConverter().convert(transitionMapStr, eol: "\n");
		var tokens = list[0];
		//print("${list[0][3]}");
		for(int row = 1; row < list.length; row++) {
			var state = list[row][0] as String;
			for(int column = 1; column < list[row].length; column++) {
				var data = list[row][column];
				if(data == null) continue;
				var dataStr = data as String;
				if(dataStr.isNotEmpty) {
					if(dataStr == "acc") {
						transitionMap["$state${tokens[column]}"] = TransitionData(
							TransitionKind.ACCEPT
						);
						continue;
					}
					switch(dataStr[0]) {
						case "s": {
							transitionMap["$state${tokens[column]}"] = TransitionData(
								TransitionKind.SHIFT,
								value: "I${dataStr.substring(1)}"
							);
							break;
						}
						case "r": {
							var spl = dataStr.split("/");
							transitionMap["$state${tokens[column]}"] = TransitionData(
								TransitionKind.REDUCE,
								ruleLeft: spl[1],
								ruleRight: int.parse(spl[2])
							);
							break;
						}
					}
				}
			}
		}
		// transitionMap.forEach((key, value) {
		// 	print("$key : $value");
		// });
	}

	String parse(List<TokenData> input, Map<String, String> cellMap) {
		var parsed = parseInternal(input);
		if(parsed == null) return null;
		return parsed.toExcel(cellMap);
	}

	NodeInternal parseInternal(List<TokenData> input) {
		var stack = Queue<StackData>();
		var nodeStack = Queue<NodeInternal>();
		var parseIndex = 0;
		var accepted = false;
		stack.addFirst(StackData("I0", ""));
		mainLoop:
		while(parseIndex < input.length || stack.isNotEmpty) {
			var transition = transitionMap[stack.first.state + input[parseIndex].kind];
			switch(transition?.kind) {
				case TransitionKind.SHIFT: {
					stack.addFirst(StackData(transition.value, input[parseIndex].kind));
					nodeStack.addFirst(NodeInternal(
						stack.first.token,
						input[parseIndex].raw,
					));
					parseIndex++;
					break;
				}
				case TransitionKind.REDUCE: {
					var newNode = NodeInternal(
						transition.ruleLeft, null
					);
					var startStack = nodeStack.first;
					for(int i = 0; i < transition.ruleRight; i++) {
						stack.removeFirst();
						startStack = nodeStack.removeFirst();
						newNode.children.add(startStack);
					}
					var newState = transitionMap[stack.first.state + transition.ruleLeft]?.value;
					stack.addFirst(StackData(newState, transition.ruleLeft));
					nodeStack.addFirst(newNode);
					break;
				}
				case TransitionKind.ACCEPT: {
					accepted = true;
					break mainLoop;
				}
				default: {
					throw Exception("パース失敗 ${stack.first.state + input[parseIndex].kind}");
				}
			}
		}
		if(!accepted) {
			print("パース失敗だよ");
			return null;
		}
		return nodeStack.first;
	}
}

class StackData {
	final String state;
	final String token;
	StackData(this.state, this.token);
}

class TransitionData {
	final TransitionKind kind;
	final String value;
	final String ruleLeft;
	final int ruleRight;
	TransitionData(
		this.kind, {this.value,
		this.ruleLeft, this.ruleRight});
}
enum TransitionKind {
	SHIFT, REDUCE, ACCEPT
}

class NodeInternal {
	final String kind;
	final String value;
	List<NodeInternal> children = [];
	NodeInternal(this.kind, this.value);

	String toExcel(Map<String,String> cellMap) {
		//print("$kind:$value:${children.length}");
		switch(kind) {
			case "Expression": {
				return children[0].toExcel(cellMap);
			}
			case "BinaryExpression": {
				if(children.length == 1) {
					return children[0].toExcel(cellMap);
				}
				var op = children[1].value == "\\cdot" ? "*" : children[1].value;
				return children[2].toExcel(cellMap) + op + children[0].toExcel(cellMap);
			}
			case "UnaryExpression": {
				if(children.length == 1) {
					return children[0].toExcel(cellMap);
				}
				if(children[1].value == "!") {
					return "FACT(${children[0].toExcel(cellMap)})";
				}
				return children[1].value + children[0].toExcel(cellMap);
			}
			case "IndexExpression": {
				if(children.length == 1) {
					return children[0].toExcel(cellMap);
				}
				if(children[1].value == "^") {
					return children[2].toExcel(cellMap) + "^" + children[0].toExcel(cellMap);
				}
				return children[2].toExcel(cellMap);
			}
			case "PrimaryExpression": {
				return children[0].toExcel(cellMap);
			}
			case "SeriesExpression": {
				if(children.length == 1) {
					return children[0].toExcel(cellMap);
				}
				return children[1].toExcel(cellMap) + "*" + children[0].toExcel(cellMap);
			}
			case "SingleExpression": {
				if(children.length == 1) {
					return children[0].toExcel(cellMap);
				}
				if(children.length == 2) {
					return "()";
				}
				if(children[2].value == "\\left|") {
					return "ABS(${children[1].toExcel(cellMap)})";
				}
				return "(${children[1].toExcel(cellMap)})";
			}
			case "NumberLiteral": {
				return value;
			}
			case "CharacterLiteral": {
				if(cellMap[value]?.isEmpty == true) {
					return value;
				}
				return cellMap[value];
			}
			case "FunctionExpression": {
				if(children.length == 1) {
					if(children[0].value == "\\pi") {
						return "PI()";
					}
					throw Exception("Excel変換失敗");
				}
				var func = children.last.value;
				if(func == "\\frac") {
					return "(${children[4].toExcel(cellMap)})/(${children[1].toExcel(cellMap)})";
				}
				if(func == "\\sqrt") {
					if(children.length == 4) {
						return "SQRT(${children[1].toExcel(cellMap)})";
					}
					return "POWER(${children[4].toExcel(cellMap)},1/(${children[1].toExcel(cellMap)}))";
				}
				if(func == "\\log") {
					if(children.length == 2) {
						return "LOG(${children[0].toExcel(cellMap)})";
					}
					return "LOG(${children[0].toExcel(cellMap)},${children[1].toExcel(cellMap)})";
				}
				if(func == "\\sin") return "SIN(${children[0].toExcel(cellMap)})";
				if(func == "\\cos") return "COS(${children[0].toExcel(cellMap)})";
				if(func == "\\tan") return "TAN(${children[0].toExcel(cellMap)})";
				if(func == "\\arcsin") return "ASIN(${children[0].toExcel(cellMap)})";
				if(func == "\\arccos") return "ACOS(${children[0].toExcel(cellMap)})";
				if(func == "\\arctan") return "ATAN(${children[0].toExcel(cellMap)})";
				if(func == "\\sinh") return "SINH(${children[0].toExcel(cellMap)})";
				if(func == "\\cosh") return "COSH(${children[0].toExcel(cellMap)})";
				if(func == "\\tanh") return "TANH(${children[0].toExcel(cellMap)})";
				if(func == "\\csc") return "CSC(${children[0].toExcel(cellMap)})";
				if(func == "\\sec") return "SEC(${children[0].toExcel(cellMap)})";
				if(func == "\\cot") return "COT(${children[0].toExcel(cellMap)})";
				if(func == "\\csch") return "CSCH(${children[0].toExcel(cellMap)})";
				if(func == "\\sech") return "SECH(${children[0].toExcel(cellMap)})";
				if(func == "\\coth") return "COTH(${children[0].toExcel(cellMap)})";
				if(func == "\\exp") return "EXP(${children[0].toExcel(cellMap)})";
				if(func == "\\ln") return "LN(${children[0].toExcel(cellMap)})";
				throw Exception("非対応の関数です: $func");
			}
			default: {
				throw Exception("不明 $kind");
			}
		}
	}
}

const String transitionMapStr = '''
,"+","-","\\cdot","!","^","_","NumberLiteral","CharacterLiteral","(",")","\\left(","\\right)","\\left|","\\right|","{","}","F0Name","F1Name","\\frac","\\sqrt","[","]","\\log",\$,"Expression","BinaryExpression","UnaryExpression","IndexExpression","PrimaryExpression","SeriesExpression","SingleExpression","FunctionExpression",
I0,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,"s1","s2","s3","s4","s8","s9","s10","s13",
I1,,,,,,,,,,,,,,,,,,,,,,,,"acc",,,,,,,,,
I2,"s23","s24","s25",,,,,,,"r/Expression/1",,"r/Expression/1",,"r/Expression/1",,"r/Expression/1",,,,,,"r/Expression/1",,"r/Expression/1",,,,,,,,,
I3,"r/BinaryExpression/1","r/BinaryExpression/1","r/BinaryExpression/1",,,,,,,"r/BinaryExpression/1",,"r/BinaryExpression/1",,"r/BinaryExpression/1",,"r/BinaryExpression/1",,,,,,"r/BinaryExpression/1",,"r/BinaryExpression/1",,,,,,,,,
I4,"r/UnaryExpression/1","r/UnaryExpression/1","r/UnaryExpression/1",,"s26","s27",,,,"r/UnaryExpression/1",,"r/UnaryExpression/1",,"r/UnaryExpression/1",,"r/UnaryExpression/1",,,,,,"r/UnaryExpression/1",,"r/UnaryExpression/1",,,,,,,,,
I5,,,,,,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,,"s28","s8","s9","s10","s13",
I6,,,,,,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,,"s29","s8","s9","s10","s13",
I7,,,,,,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,,"s30","s8","s9","s10","s13",
I8,"r/IndexExpression/1","r/IndexExpression/1","r/IndexExpression/1",,"r/IndexExpression/1","r/IndexExpression/1",,,,"r/IndexExpression/1",,"r/IndexExpression/1",,"r/IndexExpression/1",,"r/IndexExpression/1",,,,,,"r/IndexExpression/1",,"r/IndexExpression/1",,,,,,,,,
I9,"r/PrimaryExpression/1","r/PrimaryExpression/1","r/PrimaryExpression/1",,"r/PrimaryExpression/1","r/PrimaryExpression/1","s11","s12","s14","r/PrimaryExpression/1","s15","r/PrimaryExpression/1","s16","r/PrimaryExpression/1","s17","r/PrimaryExpression/1","s18","s19","s20","s21",,"r/PrimaryExpression/1","s22","r/PrimaryExpression/1",,,,,,,"s31","s13",
I10,"r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1",,"r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1",,"r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1",,,,,,,,,
I11,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,,,,,,,,
I12,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,,,,,,,,
I13,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,,,,,,,,
I14,"s5","s6",,"s7",,,"s11","s12","s14","s32","s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,"s33","s2","s3","s4","s8","s9","s10","s13",
I15,"s5","s6",,"s7",,,"s11","s12","s14",,"s15","s34","s16",,"s17",,"s18","s19","s20","s21",,,"s22",,"s35","s2","s3","s4","s8","s9","s10","s13",
I16,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,"s36","s2","s3","s4","s8","s9","s10","s13",
I17,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17","s37","s18","s19","s20","s21",,,"s22",,"s38","s2","s3","s4","s8","s9","s10","s13",
I18,"r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1",,"r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1",,"r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1",,,,,,,,,
I19,,,,,,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,,,,,"s39","s13",
I20,,,,,,,,,,,,,,,"s40",,,,,,,,,,,,,,,,,,
I21,,,,,,,,,,,,,,,"s41",,,,,,"s42",,,,,,,,,,,,
I22,,,,,,"s44","s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,,,,,"s43","s13",
I23,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,"s45","s4","s8","s9","s10","s13",
I24,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,"s46","s4","s8","s9","s10","s13",
I25,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,"s47","s4","s8","s9","s10","s13",
I26,,,,,,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,,,"s48","s9","s10","s13",
I27,,,,,,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,,,"s49","s9","s10","s13",
I28,"r/UnaryExpression/2","r/UnaryExpression/2","r/UnaryExpression/2",,"s26","s27",,,,"r/UnaryExpression/2",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,,,,
I29,"r/UnaryExpression/2","r/UnaryExpression/2","r/UnaryExpression/2",,"s26","s27",,,,"r/UnaryExpression/2",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,,,,
I30,"r/UnaryExpression/2","r/UnaryExpression/2","r/UnaryExpression/2",,"s26","s27",,,,"r/UnaryExpression/2",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,,,,
I31,"r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2",,"r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2",,"r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2",,,,,,,,,
I32,"r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2",,"r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2",,"r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2",,,,,,,,,
I33,,,,,,,,,,"s50",,,,,,,,,,,,,,,,,,,,,,,
I34,"r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2",,"r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2",,"r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2",,,,,,,,,
I35,,,,,,,,,,,,"s51",,,,,,,,,,,,,,,,,,,,,
I36,,,,,,,,,,,,,,"s52",,,,,,,,,,,,,,,,,,,
I37,"r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2",,"r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2",,"r/SingleExpression/2","r/SingleExpression/2","r/SingleExpression/2",,,,,,,,,
I38,,,,,,,,,,,,,,,,"s53",,,,,,,,,,,,,,,,,
I39,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,,,,,,,,
I40,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,"s54","s2","s3","s4","s8","s9","s10","s13",
I41,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,"s55","s2","s3","s4","s8","s9","s10","s13",
I42,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,"s56","s2","s3","s4","s8","s9","s10","s13",
I43,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,,,,,,,,
I44,,,,,,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,,,,,"s57","s13",
I45,"r/BinaryExpression/3","r/BinaryExpression/3","r/BinaryExpression/3",,,,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,,,,
I46,"r/BinaryExpression/3","r/BinaryExpression/3","r/BinaryExpression/3",,,,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,,,,
I47,"r/BinaryExpression/3","r/BinaryExpression/3","r/BinaryExpression/3",,,,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,,,,
I48,"r/IndexExpression/3","r/IndexExpression/3","r/IndexExpression/3",,"r/IndexExpression/3","r/IndexExpression/3",,,,"r/IndexExpression/3",,"r/IndexExpression/3",,"r/IndexExpression/3",,"r/IndexExpression/3",,,,,,"r/IndexExpression/3",,"r/IndexExpression/3",,,,,,,,,
I49,"r/IndexExpression/3","r/IndexExpression/3","r/IndexExpression/3",,"r/IndexExpression/3","r/IndexExpression/3",,,,"r/IndexExpression/3",,"r/IndexExpression/3",,"r/IndexExpression/3",,"r/IndexExpression/3",,,,,,"r/IndexExpression/3",,"r/IndexExpression/3",,,,,,,,,
I50,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,,,,,,,,
I51,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,,,,,,,,
I52,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,,,,,,,,
I53,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,"r/SingleExpression/3","r/SingleExpression/3","r/SingleExpression/3",,,,,,,,,
I54,,,,,,,,,,,,,,,,"s58",,,,,,,,,,,,,,,,,
I55,,,,,,,,,,,,,,,,"s59",,,,,,,,,,,,,,,,,
I56,,,,,,,,,,,,,,,,,,,,,,"s60",,,,,,,,,,,
I57,,,,,,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,,,,,,,"s61","s13",
I58,,,,,,,,,,,,,,,"s62",,,,,,,,,,,,,,,,,,
I59,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,,,,,,,,
I60,,,,,,,,,,,,,,,"s63",,,,,,,,,,,,,,,,,,
I61,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,,,,,,,,
I62,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,"s64","s2","s3","s4","s8","s9","s10","s13",
I63,"s5","s6",,"s7",,,"s11","s12","s14",,"s15",,"s16",,"s17",,"s18","s19","s20","s21",,,"s22",,"s65","s2","s3","s4","s8","s9","s10","s13",
I64,,,,,,,,,,,,,,,,"s66",,,,,,,,,,,,,,,,,
I65,,,,,,,,,,,,,,,,"s67",,,,,,,,,,,,,,,,,
I66,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,,,,,,,,
I67,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,,,,,,,,
''';
