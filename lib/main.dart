
import 'dart:html';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tex_to_excel/parser.dart';
import 'package:tex_to_excel/tokenizer.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Desmos2Excel',
      locale: Locale("ja", "JP"),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale("ja", "JP"),
      ],
      theme: ThemeData(
        fontFamily: "Noto Sans JP",
        primarySwatch: Colors.green,
      ),
      home: MyHomePage(),
      onGenerateRoute: (settings) {
        print("path: ${settings.name}");
        var paths = settings.name.split('?');
        if(paths.length != 2) return null;
        var queryParameters = Uri.splitQueryString(paths[1]);
        return MaterialPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => new MyHomePage(params: queryParameters)
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.params}) : super(key: key);
  final Map<String,String> params;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String dataStr = "initial";
  Parser parser;
  String texStr = "";
  String outputStr = "=";
  String errorStr = "";

  TextEditingController texController;
  List<VariableData> variables = [];
  Map<String, VariableData> variablesMap = {};

  @override
  void initState() {
    super.initState();
    parser = Parser();
    texController = TextEditingController();

    texController.addListener(() {
      try {
        var tokenizer = Tokenizer(texController.text);
        variables.clear();
        for(String c in tokenizer.getVariables()) {
          if(variablesMap.containsKey(c)) {
            variables.add(variablesMap[c]);
          }
          else {
            var newVar = VariableData(c);
            variablesMap[c] = newVar;
            variables.add(newVar);
          }
        }
        setState(() { });
      } catch(e) {
        print("内部エラー: $e");
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print(widget.params);
    widget.params?.entries?.where((e) => e.key != "formula")?.forEach((e) {
      variablesMap[e.key] = VariableData(e.key, e.value);
    });
    print(variablesMap);
    if(widget.params?.containsKey("formula") == true) {
      texController.text = widget.params["formula"];
      texStr = texController.text;
    }
  }

  @override
  void dispose() {
    texController.dispose();
    variablesMap.forEach((key, value) { value.dispose(); });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Desmos2Excel"),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton(
              child: Text("Texの書き方", style: TextStyle(color: Colors.white),),
              onPressed: () async {
                var url = "https://cns-guide.sfc.keio.ac.jp/2001/11/4/1.html";
                if(await canLaunch(url)) await launch(url);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton(
              child: Text("Desmos", style: TextStyle(color: Colors.white),),
              onPressed: () async {
                var url = "https://www.desmos.com/calculator";
                if(await canLaunch(url)) await launch(url);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton(
              child: Text("ライセンス", style: TextStyle(color: Colors.white),),
              onPressed: () {
                showLicensePage(
                  context: context,
                  applicationName: 'Desmos2Excel', // アプリの名前
                  applicationVersion: '1.0.0', // バージョン
                  applicationLegalese: '2021 fastriver_org(fastriver.dev)', // 権利情報
                );
              },
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: [
                      Text(
                        "Desmosの数式(Tex形式)をコピペするといい感じにExcel関数に変換してくれるサイトです",
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                            "Texを入力(Desmosの数式をコピペ)",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    color: Colors.lightGreen.shade50,
                    child: TextField(
                      controller: texController,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 20.0
                      ),
                      decoration: InputDecoration(
                        //labelText: "Tex (Desmosの数式をコピペ):",
                        hintText: "\\frac{1}{2}",
                        suffixIcon: IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () { setState(() {
                            texStr = "";
                            texController.clear();
                          }); },
                        ),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(width: 2.0)
                        )
                      ),
                      onChanged: (text) {
                        setState(() {
                          texStr = text;
                        });
                      },
                    ),
                  ),
                  Text(
                    errorStr,
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                  Text(
                      "↓",
                    style: Theme.of(context).textTheme.headline3,
                  ),
                  Card(
                    color: Colors.lightGreen.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                "Excel関数",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  outputStr,
                                  style: Theme.of(context).textTheme.bodyText2,
                                ),
                              ),
                              IconButton(
                                  icon: Icon(Icons.copy),
                                  onPressed: () async {
                                    final data = ClipboardData(text: outputStr);
                                    await Clipboard.setData(data);
                                    final snackBar = SnackBar(content: Text('コピーしました'));
                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                  }
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: OutlinedButton(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                            "変換する",
                          style: TextStyle(
                            fontSize: 32,
                          ),
                        ),
                      ),
                      onPressed: () {
                        if(texStr.isEmpty) {
                          return;
                        }
                        try {
                          var tokenizer = Tokenizer(texStr);
                          var cellMap = Map<String,String>();
                          for (var value in variables) {
                            cellMap[value.symbol] = value.replaced;
                          }
                          print("t=${tokenizer.tokenized.map((e) => e.kind)}");
                          var parsed = parser.parse(
                              tokenizer.tokenized,
                            cellMap
                          ) ?? "failed";
                          setState(() {
                            errorStr = "";
                            outputStr = "=" + parsed;
                          });
                        } catch(e) {
                          setState(() {
                            errorStr = "エラー：$e";
                          });
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      label: Text("数式を共有..."),
                      icon: Icon(Icons.share),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("共有"),
                            content: SingleChildScrollView(
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text("関数のみ"),
                                    subtitle: SelectableText(createShareLink(texStr)),
                                    trailing: IconButton(
                                      icon: Icon(Icons.copy),
                                        onPressed: () async {
                                          final data = ClipboardData(
                                              text: createShareLink(texStr)
                                          );
                                          await Clipboard.setData(data);
                                          final snackBar = SnackBar(content: Text('コピーしました'));
                                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                        }
                                    ),
                                  ),
                                  ListTile(
                                    title: Text("全て"),
                                    subtitle: SelectableText(createShareLink(texStr, variables)),
                                    trailing: IconButton(
                                        icon: Icon(Icons.copy),
                                        onPressed: () async {
                                          final data = ClipboardData(
                                              text: createShareLink(texStr, variables)
                                          );
                                          await Clipboard.setData(data);
                                          final snackBar = SnackBar(content: Text('コピーしました'));
                                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                        }
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text("閉じる")
                              )
                            ],
                          )
                        );
                      },
                    ),
                  ),
                  //下のテーブル
                  Table(
                    border: TableBorder.all(
                      color: Colors.blueGrey.shade200
                    ),
                    columnWidths: {
                      0: FixedColumnWidth(100),
                      1: FixedColumnWidth(50)
                    },
                    defaultColumnWidth: FixedColumnWidth(200),
                    children: [
                      TableRow(
                        children: [
                          TableCell(
                            child: Center(child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("変数"),
                            )),
                            verticalAlignment: TableCellVerticalAlignment.middle,
                          ),
                          TableCell(
                            child: Center(child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("->"),
                            )),
                            verticalAlignment: TableCellVerticalAlignment.middle,
                          ),
                          TableCell(
                            child: Center(child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("対応するセル"),
                            )),
                            verticalAlignment: TableCellVerticalAlignment.middle,
                          ),
                        ]
                      ),
                      ...variables.map((e) => TableRow(
                          children: [
                            TableCell(
                              child: Center(child: Text(e.symbol)),
                              verticalAlignment: TableCellVerticalAlignment.middle,
                            ),
                            TableCell(
                              child: Center(child: Text("->")),
                              verticalAlignment: TableCellVerticalAlignment.middle,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: TextField(
                                controller: e.controller,
                                onChanged: (value) {
                                  e.replaced = value;
                                },
                                decoration: InputDecoration(
                                  hintText: "A\$2"
                                ),
                              ),
                            )
                          ]
                      )).toList()
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 8, right: 8, top: 32, bottom: 24
                    ),
                    child: Text(
                      "使い方\n\n"+
                        "1. Desmos(desmos.com)で数式を打ちます\n" +
                        "2. 数式を全選択してコピーします\n" +
                        "3. 本サイトの上の入力欄にペーストします(or直打ち)\n" +
                        "4. 下の表で変数をセルにマッピングします\n" +
                        "5. [変換する]を押して関数を生成\n" +
                        "6. 式をコピーしてExcelに貼り付け\n"
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String createShareLink(String formula, [List<VariableData> variables]) {
    var base = "https://desmos2excel.fastriver.dev/#/";
    var encodedFormula = Uri.encodeComponent(formula);
    if(variables == null || variables.isEmpty) {
      return base + "?formula=$encodedFormula";
    }
    var variableStr = "";
    variables.forEach((e) {
      if(e.replaced.isNotEmpty) {
        variableStr += "&${e.symbol}=${Uri.encodeComponent(e.replaced)}";
      }
    });
    return base + "?formula=$encodedFormula" + variableStr;
  }
}

class VariableData {
  final String symbol;
  TextEditingController controller;
  String replaced;

  VariableData(this.symbol, [String defaultStr]) {
    if(defaultStr != null) {
      controller = TextEditingController(text: defaultStr);
      replaced = defaultStr;
    }
    else {
      controller = TextEditingController();
      replaced = "";
    }
  }

  void dispose() {
    controller.dispose();
  }
}
