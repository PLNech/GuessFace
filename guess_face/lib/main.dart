import 'package:algolia/algolia.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  static final Algolia _algolia = Algolia.init(
    applicationId: 'latency',
    apiKey: '0f7fbe1c34e2e1ade92120bb6b221d06',
  );

  static Future<AlgoliaQuerySnapshot> _loadAlgolians() async {
    AlgoliaQuerySnapshot snap = await _algolia.instance
        .index("algolia.com-about-page")
        .search("")
        .setHitsPerPage(1000)
        .getObjects();

    print("Got hits: ${snap.hits.length}");
    return snap;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome to Flutter',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Welcome to Flutter'),
        ),
        body: Center(child: GuessWidget()),
      ),
    );
  }
}

class GuessWidget extends StatefulWidget {
  @override
  GuessState createState() => new GuessState();
}

class GuessState extends State<GuessWidget> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AlgoliaQuerySnapshot>(
        future: MyApp._loadAlgolians(),
        builder: (context, snapshot) {
          return Text('Loaded ${snapshot.data.nbHits} algolians!');
        });
    // TODO: implement build
    /**
     * - Load a user, and 3 random names
     * - Keep a currentScore
     * - Keep a currentTurn (at 5, the game should display end screen)
     */
  }
}
