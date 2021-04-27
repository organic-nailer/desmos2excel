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
			case "SeriesExpression": {
				if(children.length == 1) {
					return children[0].toExcel(cellMap);
				}
				return children[1].toExcel(cellMap) + "*" + children[0].toExcel(cellMap);
			}
			case "SingleExpression": {
				return children[0].toExcel(cellMap);
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
,"+","-","\\cdot","!","^","_","(",")","\\left|","\\right|","{","}","NumberLiteral","CharacterLiteral","F0Name","F1Name","\\frac","\\sqrt","[","]","\\log",\$,"Expression","BinaryExpression","UnaryExpression","IndexExpression","PrimaryExpression","SeriesExpression","SingleExpression","FunctionExpression",
I0,"s5","s6",,"s7",,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,"s1","s2","s3","s4","s8","s9","s13","s16",
I1,,,,,,,,,,,,,,,,,,,,,,"acc",,,,,,,,,
I2,"s22","s23","s24",,,,,"r/Expression/1",,"r/Expression/1",,"r/Expression/1",,,,,,,,"r/Expression/1",,"r/Expression/1",,,,,,,,,
I3,"r/BinaryExpression/1","r/BinaryExpression/1","r/BinaryExpression/1",,,,,"r/BinaryExpression/1",,"r/BinaryExpression/1",,"r/BinaryExpression/1",,,,,,,,"r/BinaryExpression/1",,"r/BinaryExpression/1",,,,,,,,,
I4,"r/UnaryExpression/1","r/UnaryExpression/1","r/UnaryExpression/1",,"s25","s26",,"r/UnaryExpression/1",,"r/UnaryExpression/1",,"r/UnaryExpression/1",,,,,,,,"r/UnaryExpression/1",,"r/UnaryExpression/1",,,,,,,,,
I5,,,,,,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,,"s27","s8","s9","s13","s16",
I6,,,,,,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,,"s28","s8","s9","s13","s16",
I7,,,,,,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,,"s29","s8","s9","s13","s16",
I8,"r/IndexExpression/1","r/IndexExpression/1","r/IndexExpression/1",,"r/IndexExpression/1","r/IndexExpression/1",,"r/IndexExpression/1",,"r/IndexExpression/1",,"r/IndexExpression/1",,,,,,,,"r/IndexExpression/1",,"r/IndexExpression/1",,,,,,,,,
I9,"r/PrimaryExpression/1","r/PrimaryExpression/1","r/PrimaryExpression/1",,"r/PrimaryExpression/1","r/PrimaryExpression/1","r/PrimaryExpression/1","r/PrimaryExpression/1","r/PrimaryExpression/1","r/PrimaryExpression/1","r/PrimaryExpression/1","r/PrimaryExpression/1","s14","s15","s17","s18","s19","s20",,"r/PrimaryExpression/1","s21","r/PrimaryExpression/1",,,,,,,"s30","s16",
I10,"s5","s6",,"s7",,,"s10","s31","s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,"s32","s2","s3","s4","s8","s9","s13","s16",
I11,"s5","s6",,"s7",,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,"s33","s2","s3","s4","s8","s9","s13","s16",
I12,"s5","s6",,"s7",,,"s10",,"s11",,"s12","s34","s14","s15","s17","s18","s19","s20",,,"s21",,"s35","s2","s3","s4","s8","s9","s13","s16",
I13,"r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1",,"r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1",,"r/SeriesExpression/1","r/SeriesExpression/1","r/SeriesExpression/1",,,,,,,,,
I14,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,,,,,,,,
I15,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,,,,,,,,
I16,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,"r/SingleExpression/1","r/SingleExpression/1","r/SingleExpression/1",,,,,,,,,
I17,"r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1",,"r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1",,"r/FunctionExpression/1","r/FunctionExpression/1","r/FunctionExpression/1",,,,,,,,,
I18,,,,,,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,,,"s36","s9","s13","s16",
I19,,,,,,,,,,,"s37",,,,,,,,,,,,,,,,,,,,
I20,,,,,,,,,,,"s38",,,,,,,,"s39",,,,,,,,,,,,
I21,,,,,,"s41","s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,,,"s40","s9","s13","s16",
I22,"s5","s6",,"s7",,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,"s42","s4","s8","s9","s13","s16",
I23,"s5","s6",,"s7",,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,"s43","s4","s8","s9","s13","s16",
I24,"s5","s6",,"s7",,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,"s44","s4","s8","s9","s13","s16",
I25,,,,,,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,,,"s45","s9","s13","s16",
I26,,,,,,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,,,"s46","s9","s13","s16",
I27,"r/UnaryExpression/2","r/UnaryExpression/2","r/UnaryExpression/2",,"s25","s26",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,,,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,,,,
I28,"r/UnaryExpression/2","r/UnaryExpression/2","r/UnaryExpression/2",,"s25","s26",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,,,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,,,,
I29,"r/UnaryExpression/2","r/UnaryExpression/2","r/UnaryExpression/2",,"s25","s26",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,,,"r/UnaryExpression/2",,"r/UnaryExpression/2",,,,,,,,,
I30,"r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2",,"r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2",,"r/SeriesExpression/2","r/SeriesExpression/2","r/SeriesExpression/2",,,,,,,,,
I31,"r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2",,"r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2",,"r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2",,,,,,,,,
I32,,,,,,,,"s47",,,,,,,,,,,,,,,,,,,,,,,
I33,,,,,,,,,,"s48",,,,,,,,,,,,,,,,,,,,,
I34,"r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2",,"r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2",,"r/PrimaryExpression/2","r/PrimaryExpression/2","r/PrimaryExpression/2",,,,,,,,,
I35,,,,,,,,,,,,"s49",,,,,,,,,,,,,,,,,,,
I36,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,,,,,,,,
I37,"s5","s6",,"s7",,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,"s50","s2","s3","s4","s8","s9","s13","s16",
I38,"s5","s6",,"s7",,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,"s51","s2","s3","s4","s8","s9","s13","s16",
I39,"s5","s6",,"s7",,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,"s52","s2","s3","s4","s8","s9","s13","s16",
I40,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,"r/FunctionExpression/2","r/FunctionExpression/2","r/FunctionExpression/2",,,,,,,,,
I41,,,,,,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,,,"s53","s9","s13","s16",
I42,"r/BinaryExpression/3","r/BinaryExpression/3","r/BinaryExpression/3",,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,,,,
I43,"r/BinaryExpression/3","r/BinaryExpression/3","r/BinaryExpression/3",,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,,,,
I44,"r/BinaryExpression/3","r/BinaryExpression/3","r/BinaryExpression/3",,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,,,"r/BinaryExpression/3",,"r/BinaryExpression/3",,,,,,,,,
I45,"r/IndexExpression/3","r/IndexExpression/3","r/IndexExpression/3",,"r/IndexExpression/3","r/IndexExpression/3",,"r/IndexExpression/3",,"r/IndexExpression/3",,"r/IndexExpression/3",,,,,,,,"r/IndexExpression/3",,"r/IndexExpression/3",,,,,,,,,
I46,"r/IndexExpression/3","r/IndexExpression/3","r/IndexExpression/3",,"r/IndexExpression/3","r/IndexExpression/3",,"r/IndexExpression/3",,"r/IndexExpression/3",,"r/IndexExpression/3",,,,,,,,"r/IndexExpression/3",,"r/IndexExpression/3",,,,,,,,,
I47,"r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3",,"r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3",,"r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3",,,,,,,,,
I48,"r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3",,"r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3",,"r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3",,,,,,,,,
I49,"r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3",,"r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3",,"r/PrimaryExpression/3","r/PrimaryExpression/3","r/PrimaryExpression/3",,,,,,,,,
I50,,,,,,,,,,,,"s54",,,,,,,,,,,,,,,,,,,
I51,,,,,,,,,,,,"s55",,,,,,,,,,,,,,,,,,,
I52,,,,,,,,,,,,,,,,,,,,"s56",,,,,,,,,,,
I53,,,,,,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,,,,,"s57","s9","s13","s16",
I54,,,,,,,,,,,"s58",,,,,,,,,,,,,,,,,,,,
I55,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,,,,,,,,
I56,,,,,,,,,,,"s59",,,,,,,,,,,,,,,,,,,,
I57,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,"r/FunctionExpression/4","r/FunctionExpression/4","r/FunctionExpression/4",,,,,,,,,
I58,"s5","s6",,"s7",,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,"s60","s2","s3","s4","s8","s9","s13","s16",
I59,"s5","s6",,"s7",,,"s10",,"s11",,"s12",,"s14","s15","s17","s18","s19","s20",,,"s21",,"s61","s2","s3","s4","s8","s9","s13","s16",
I60,,,,,,,,,,,,"s62",,,,,,,,,,,,,,,,,,,
I61,,,,,,,,,,,,"s63",,,,,,,,,,,,,,,,,,,
I62,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,,,,,,,,
I63,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,"r/FunctionExpression/7","r/FunctionExpression/7","r/FunctionExpression/7",,,,,,,,,
''';
