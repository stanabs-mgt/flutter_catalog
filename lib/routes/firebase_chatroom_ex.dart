import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import './firebase_constants.dart';
import '../my_route.dart';

final kFirebaseAuth = FirebaseAuth.instance;
final kGoogleSignIn = GoogleSignIn();

// NOTE: to add firebase support, first go to firebase console, generate the
// firebase json file, and add configuration lines in the gradle files.
// C.f. this commit: https://github.com/X-Wei/flutter_catalog/commit/48792cbc0de62fc47e0e9ba2cd3718117f4d73d1.
class FirebaseChatroomExample extends MyRoute {
  const FirebaseChatroomExample(
      [String sourceFile = 'lib/routes/firebase_chatroom_ex.dart'])
      : super(sourceFile);

  @override
  get title => 'Chat room';

  @override
  get description => 'Chat room with firebase realtime db';

  @override
  get links => {
        'FriendlyChat codelab': 'https://github.com/flutter/friendlychat-steps',
        "Google I/O'17 video": 'https://www.youtube.com/watch?v=w2TcYP8qiRI',
      };

  @override
  Widget buildMyRouteContent(BuildContext context) {
    return ChatPage();
  }
}

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static final _firebaseMsgDbRef = kFirebaseDbRef.child('messages');

  FirebaseUser _user;
  final TextEditingController _textController = TextEditingController();
  bool _isComposing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      appBar: AppBar(
        backgroundColor: Colors.orangeAccent,
        leading: IconButton(
          icon: Icon(Icons.info),
          onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: Text('Note'),
                      content: Text(
                          'This chat room is only for demo purpose.\n\n'
                          'The chat messages are publicly available, and they '
                          'can be deleted at any time by the firebase admin.'),
                      actions: <Widget>[
                        FlatButton(
                          child: Text('OK'),
                          onPressed: () => Navigator.of(ctx).pop(),
                        )
                      ],
                    ),
              ),
        ),
        title: Text('Chat room'),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            _buildMessagesList(),
            Divider(height: 2.0),
            _buildComposeMsgRow()
          ],
        ),
      ),
    );
  }

  // Builds the list of chat messages.
  Widget _buildMessagesList() {
    return Flexible(
      child: FirebaseAnimatedList(
        query: _firebaseMsgDbRef,
        sort: (a, b) => b.key.compareTo(a.key),
        padding: EdgeInsets.all(8.0),
        reverse: true,
        itemBuilder: (BuildContext ctx, DataSnapshot snapshot,
                Animation<double> animation, int idx) =>
            _messageFromSnapshot(snapshot, animation),
      ),
    );
  }

  // Returns the UI of one message from a data snapshot.
  Widget _messageFromSnapshot(
      DataSnapshot snapshot, Animation<double> animation) {
    final String senderName = snapshot.value['senderName'];
    final String msgText = snapshot.value['text'];
    final sentTime = snapshot.value['timestamp'];
    final String senderPhotoUrl = snapshot.value['senderPhotoUrl'];
    final messageUI = Padding(
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: senderPhotoUrl != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(senderPhotoUrl),
                  )
                : CircleAvatar(
                    child: Text(senderName[0]),
                  ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(senderName, style: Theme.of(context).textTheme.subhead),
                Text(
                  DateTime.fromMillisecondsSinceEpoch(sentTime).toString(),
                  style: Theme.of(context).textTheme.caption,
                ),
                Text(msgText),
              ],
            ),
          ),
        ],
      ),
    );
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ),
      axisAlignment: 0.0,
      child: messageUI,
    );
  }

  // Builds the row for composing and sending message.
  Widget _buildComposeMsgRow() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor),
      child: Row(
        children: <Widget>[
          Flexible(
            child: TextField(
              keyboardType: TextInputType.multiline,
              maxLines: 3,
              decoration: InputDecoration.collapsed(hintText: "Send a message"),
              controller: _textController,
              onChanged: (String text) =>
                  setState(() => _isComposing = text.length > 0),
              onSubmitted: _onTextMsgSubmitted,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _isComposing
                ? () => _onTextMsgSubmitted(_textController.text)
                : null,
          ),
        ],
      ),
    );
  }

  // Triggered when text is submitted (send button pressed).
  Future<Null> _onTextMsgSubmitted(String text) async {
    // Make sure _user is not null.
    if (this._user == null) {
      this._user = await kFirebaseAuth.currentUser();
    }
    if (this._user == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Login required'),
              content: Text('To send messages you need to first log in.\n\n'
                  'Go to the "Firebase login" example, and log in from there. '
                  'Then you will then be able to send messages.'),
              actions: <Widget>[
                FlatButton(
                  child: Text('OK'),
                  onPressed: () => Navigator.of(ctx).pop(),
                )
              ],
            ),
      );
      return;
    }
    // Clear input text field.
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
    // Send message to firebase realtime database.
    _firebaseMsgDbRef.push().set({
      'senderId': this._user.uid,
      'senderName': this._user.displayName,
      'senderPhotoUrl': this._user.photoUrl,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
}