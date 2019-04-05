import 'dart:math';

import 'package:algolia/algolia.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:transparent_image/transparent_image.dart';

void main() => runApp(MyApp());

const imageWidth = 200;
const defaultHint = "Hint";

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
      home: HomeWidget(),
      routes: <String, WidgetBuilder>{
        '/game': (BuildContext context) => Scaffold(
              appBar: AppBar(
                title: Text('Guess an Algolian 🙈'),
              ),
              body: Center(child: GuessWidget()),
            )
      },
    );
  }
}

class HomeWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Guess that Face 🙃')),
        body: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
              Text("Can you guess your colleagues' names?",
                  style: Theme.of(context).textTheme.headline,
                  textAlign: TextAlign.center),
              Padding(padding: EdgeInsets.symmetric(vertical: 10.0)),
              RaisedButton(
                  child: Text("Play 🔥",
                      style: Theme.of(context).textTheme.button),
                  onPressed: () => {Navigator.of(context).pushNamed("/game")}),
            ])));
  }
}

class GuessWidget extends StatefulWidget {
  @override
  GuessState createState() => new GuessState();
}

class GuessState extends State<GuessWidget> {
  var score = 0;
  var gotHint = false;
  var roundPoints = 10;
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

          var data = guessData.data;
          return Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(children: <Widget>[
                FadeInImage.memoryNetwork(
                    placeholder: kTransparentImage,
                    image: data.imageURL,
                    fit: BoxFit.fill,
                    width: imageWidth.toDouble()),
                Padding(padding: EdgeInsets.symmetric(vertical: 10.0)),
                Text('Guess the name 🧐',
                    style: Theme.of(context).textTheme.headline),
                Padding(padding: EdgeInsets.symmetric(vertical: 10.0)),
                Text(_buildScoreString(),
                    style: Theme.of(context).textTheme.subhead),
                FlatButton(
                  child: Text(hintText),
                  onPressed: () => {setState(() {
                    var hit = guessData.data.guessMe.data;
                        hintText = "${hit['jobTitle']} in ${hit['division']}";
                        roundPoints = 5;
                  })},
                ),
                Expanded(
                    child: _buildSuggestionList(
                        data.options, data.guessMe.data["name"]))
              ]));
        });
    /**
     * - Keep a currentScore
     * - Keep a currentTurn (at 5, the game should display end screen)
     */
  }

  _buildSuggestionList(List<String> objects, String guessName) {
    return ListView.builder(
      itemCount: objects.length,
      padding: const EdgeInsets.all(4.0),
      itemBuilder: (context, i) {
        return _buildRow(objects[min(i, objects.length - 1)], guessName);
      },
    );
  }

  _buildRow(String name, String guessName) {
    final isRightAnswer = (name == guessName);
    return ListTile(
      title: RaisedButton(
        onPressed: () => {
              setState(() {
                round++;
                score += isRightAnswer ? roundPoints : -10;
                hintText = defaultHint;
                guessData = MyApp._loadAlgolians();
              })
            },
        color: Colors.blue,
        padding: const EdgeInsets.all(10.0),
        child: Text(name, style: Theme.of(context).textTheme.button),
      ),
    );
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
