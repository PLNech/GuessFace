import 'dart:math';

import 'package:algolia/algolia.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:transparent_image/transparent_image.dart';

void main() => runApp(MyApp());

const imageWidth = 200;
const defaultPoints = 10;
const defaultHint = "Need a Hint?";
const defaultHeadline = "Can you guess your colleagues' names?";
const ColorAlgoliaBlue = const Color(0xFF5468FF);

class MyApp extends StatelessWidget {
  static final Algolia _algolia = Algolia.init(
    applicationId: 'latency',
    apiKey: '0f7fbe1c34e2e1ade92120bb6b221d06',
  );

  static Future<GuessData> _loadAlgolians() async {
    debugPrint("Loading Algolians!");
    AlgoliaQuerySnapshot snap = await _algolia.instance
        .index("algolia.com-about-page")
        .search("")
        .setHitsPerPage(1000)
        .getObjects();
    debugPrint("Got hits: ${snap.hits.length}");

    var algolians = snap.hits..shuffle();

    // Select an Algolian with valid image
    for (var algolian in algolians) {
      if (algolian.data["gravatar"] == null) continue;
      // "https://www.gravatar.com/avatar/7f6d9be8b64f32120bd6ef07e3b3b501?d=404";
      var gravatarURL = algolian.data["gravatar"] + "?s=$imageWidth&d=404";
      if ((await http.get(gravatarURL)).statusCode == 200) {
        algolians.remove(algolian);
        var options = algolians.sublist(0, 3);
        options.add(algolian);
        return GuessData(
            gravatarURL,
            algolian,
            options.map((it) => (it.data["name"] as String)).toList()
              ..shuffle());
      }
      debugPrint("Algolian ${algolian.data["name"]} has invalid picture, next");
    }
    throw new Exception("No algolian has valid image!!1!");
  }

  //FIXME: Don't hide error with a progressindicator, rather fix async issue
  Widget getErrorWidget(BuildContext context, FlutterErrorDetails error) {
    return Center(
      child: new CircularProgressIndicator(
        value: null,
        strokeWidth: 7.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return getErrorWidget(context, errorDetails);
    };
    return MaterialApp(
      title: 'GuessFace',
      home: Scaffold(body: HomeWidget()),
      theme: ThemeData(
        primaryColor: ColorAlgoliaBlue,
      ),
      routes: <String, WidgetBuilder>{
        '/game': (BuildContext context) => Scaffold(body: GuessWidget())
      },
    );
  }
}

class HomeWidget extends StatefulWidget {
  @override
  HomeState createState() => new HomeState();
}

class HomeState extends State<HomeWidget> {
  var highScore = 0;
  var headline = defaultHeadline;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Guess that Face 🙃')),
        body: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
              _buildScoreText(),
              Padding(padding: EdgeInsets.symmetric(vertical: 10.0)),
              Text(headline,
                  style: Theme.of(context).textTheme.headline,
                  textAlign: TextAlign.center),
              Padding(padding: EdgeInsets.symmetric(vertical: 10.0)),
              RaisedButton(
                  child: Text("Play 🔥",
                      style: Theme.of(context).textTheme.button),
                  onPressed: () {
                    _navigateToGame(context);
                  }),
            ])));
  }

  void _navigateToGame(BuildContext context) async {
    final score = await Navigator.of(context).pushNamed("/game");
    //FIXME: Get score on back press / top button
    debugPrint("Got score $score!");
    setState(() {
      highScore = max(score, highScore);
      headline = "Play again?";
    });
  }

  _buildScoreText() {
    var textTheme = Theme.of(context).textTheme;
    return Text("High score: $highScore",
        style: highScore == 0 ? textTheme.body1 : textTheme.display2,
        textAlign: TextAlign.center);
  }
}

class GuessWidget extends StatefulWidget {
  @override
  GuessState createState() => new GuessState();
}

class GuessState extends State<GuessWidget> {
  var score = 0;
  var gotHint = false;
  var roundPoints = defaultPoints;
  var round = 0;
  var hintText = defaultHint;
  var guessData;

  @override
  void initState() {
    super.initState();
    guessData = MyApp._loadAlgolians();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GuessData>(
        future: guessData,
        builder: (context, guessData) {
          if (guessData.hasError) {
            debugPrint("ERROR! ${guessData.error}");
            return Text(guessData.error);
          }

          return _buildGameScreen(context, guessData.data);
        });
  }

  Scaffold _buildGameScreen(BuildContext context, GuessData data) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Guess an Algolian 🙈'),
      ),
      body: Center(
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(children: <Widget>[
                FadeInImage.memoryNetwork(
                    placeholder: kTransparentImage,
                    image: data.imageURL,
                    fit: BoxFit.fill,
                    width: imageWidth.toDouble()),
                Padding(padding: EdgeInsets.symmetric(vertical: 5.0)),
                Text(_buildScoreString(),
                    style: Theme.of(context).textTheme.subhead),
                FlatButton(
                  padding: EdgeInsets.all(0.0),
                  child: Text(hintText, style: _getStyleForHint()),
                  onPressed: () => {
                    setState(() {
                      var hit = data.guessMe.data;
                      hintText = "${hit['jobTitle']} in ${hit['division']}";
                      roundPoints = 5;
                    })
                  },
                ),
                Expanded(
                    child: _buildSuggestionList(
                        data.options, data.guessMe.data["name"])),
                FlatButton(
                  child: Text("Stop playing"),
                  onPressed: () => {Navigator.of(context).pop(score)},
                )
              ]))),
    );
  }

  TextStyle _getStyleForHint() {
    return hintText == defaultHint
        ? TextStyle(decoration: TextDecoration.underline)
        : null;
  }

  _buildSuggestionList(List<String> objects, String guessName) {
    return ListView.builder(
      itemCount: objects.length,
      itemBuilder: (context, i) {
        return _buildRow(objects[min(i, objects.length - 1)], guessName);
      },
    );
  }

  _buildRow(String name, String guessName) {
    final isRightAnswer = (name == guessName);
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 30.0),
      title: OutlineButton(
        borderSide: BorderSide(color: ColorAlgoliaBlue, width: 3.0),
        padding: EdgeInsets.all(0.0),
        onPressed: () => _updateScore(isRightAnswer, guessName),
        child: Text(name,
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Set<void> _updateScore(bool isRightAnswer, String guessName) {
    var message = isRightAnswer
        ? Text("Well played ✨")
        : new RichText(
            text: new TextSpan(
              style: new TextStyle(fontSize: 18.0),
              children: <TextSpan>[
                new TextSpan(text: "Actually, this was "),
                new TextSpan(
                    text: guessName,
                    style: new TextStyle(fontWeight: FontWeight.bold)),
                new TextSpan(text: " 🙃"),
              ],
            ),
          );
    Scaffold.of(context).showSnackBar(SnackBar(
        content: message, duration: Duration(seconds: isRightAnswer ? 1 : 5)));
    return {
      setState(() {
        round++;
        score += isRightAnswer ? roundPoints : -10;
        hintText = defaultHint;
        roundPoints = defaultPoints;
        guessData = MyApp._loadAlgolians();
      })
    };
  }

  String _buildScoreString() {
    String emoji;
    if (round == 0) {
      return "Round 1! 🚀";
    }
    var successfulRounds = (score / 10);
    if (successfulRounds >= round * 0.9) {
      emoji = '💯'; // Perfect
    } else if (successfulRounds >= round / 2) {
      emoji = '🎯'; // At least half good
    } else if (successfulRounds >= round / 3) {
      emoji = '😐'; // At least half good
    } else if (successfulRounds >= round / 4) {
      emoji = '🤔';
    } else {
      emoji = '😭';
    }
    return 'Round ${round + 1} | Score: $score $emoji';
  }
}

class GuessData {
  final String imageURL;
  final AlgoliaObjectSnapshot guessMe;
  final List<dynamic> options; //TODO: How can I type this right?

  @override
  String toString() {
    return "${guessMe.data["name"]}, $imageURL, ${options.toString()}";
  }

  GuessData(this.imageURL, this.guessMe, this.options);
}
