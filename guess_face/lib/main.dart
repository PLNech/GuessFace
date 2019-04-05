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
          return Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(children: <Widget>[
                Text('Loaded ${snapshot.data.nbHits} algolians!'),
                Expanded(child: _buildSuggestionList(snapshot))
              ]));
        });
    /**
     * - Load a user, and 3 random names
     * - Keep a currentScore
     * - Keep a currentTurn (at 5, the game should display end screen)
     */
  }

  _buildSuggestionList(AsyncSnapshot<AlgoliaQuerySnapshot> objects) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, i) {
        return _buildRow(objects.data.hits[i].data);
      },
    );
  }

  _buildRow(Map<String, dynamic> hit) {
    return ListTile(title: Text(hit["name"]));
  }
}
