// @dart=2.11
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:planestrike_flutter/game_agent.dart';

void main() {
  runApp(PlaneStrike());
}

class PlaneStrike extends StatefulWidget {
  // This widget is the root of your application.
  @override
  _PlaneStrikeState createState() => _PlaneStrikeState();
}

class _PlaneStrikeState extends State<PlaneStrike> {
  // The board should be in square shape so we only need one size
  final _boardSize = 8;
  // Number of pieces needed to form a 'plane'
  final _planePieceCount = 8;
  int _agentHits;
  int _playerHits;
  PolicyGradientAgent _policyGradientAgent;
  List<List<double>> _agentBoardState;
  List<List<double>> _agentHiddenBoardState;
  List<List<double>> _playerBoardState;
  List<List<double>> _playerHiddenBoardState;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TFLite Flutter Reference App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: _buildGameBody(),
    );
  }

  List<List<double>> _fillWithZeros() => List.generate(_boardSize, (_) => List.filled(_boardSize, 0.0));

  void _resetGame() {
    _agentHits = 0;
    _playerHits = 0;
    _policyGradientAgent = PolicyGradientAgent();
    // We keep track of 4 sets of boards (2 for each player):
    //   - *BoardState is the visible board that tracks the game progress
    //   - *HiddentBoardState is the secret board that records the true plane location
    _agentBoardState = _fillWithZeros();
    _agentHiddenBoardState = _setBoardState();
    _playerBoardState = _fillWithZeros();
    _playerHiddenBoardState = _setBoardState();
  }

  List<List<double>> _setBoardState() {
    var hiddenBoardState = _fillWithZeros();

    // Place the plane on the board
    // First, decide the plane's orientation
    //   0: heading right
    //   1: heading up
    //   2: heading left
    //   3: heading down
    var rng = new Random();
    int planeOrientation = rng.nextInt(4);

    // Figrue out the location of plane core as the '*' below
    //   | |      |      | |    ---
    //   |-*-    -*-    -*-|     |
    //   | |      |      | |    -*-
    //           ---             |
    var planeCoreX, planeCoreY;
    switch (planeOrientation) {
      case 0:
        planeCoreX = rng.nextInt(_boardSize - 2) + 1;
        planeCoreY = rng.nextInt(_boardSize - 3) + 2;
        // Populate the tail
        hiddenBoardState[planeCoreX][planeCoreY - 2] = 1;
        hiddenBoardState[planeCoreX - 1][planeCoreY - 2] = 1;
        hiddenBoardState[planeCoreX + 1][planeCoreY - 2] = 1;
        break;
      case 1:
        planeCoreX = rng.nextInt(_boardSize - 3) + 1;
        planeCoreY = rng.nextInt(_boardSize - 2) + 1;
        // Populate the tail
        hiddenBoardState[planeCoreX + 2][planeCoreY] = 1;
        hiddenBoardState[planeCoreX + 2][planeCoreY + 1] = 1;
        hiddenBoardState[planeCoreX + 2][planeCoreY - 1] = 1;
        break;
      case 2:
        planeCoreX = rng.nextInt(_boardSize - 2) + 1;
        planeCoreY = rng.nextInt(_boardSize - 3) + 1;
        // Populate the tail
        hiddenBoardState[planeCoreX][planeCoreY + 2] = 1;
        hiddenBoardState[planeCoreX - 1][planeCoreY + 2] = 1;
        hiddenBoardState[planeCoreX + 1][planeCoreY + 2] = 1;
        break;
      default:
        planeCoreX = rng.nextInt(_boardSize - 3) + 2;
        planeCoreY = rng.nextInt(_boardSize - 2) + 1;
        // Populate the tail
        hiddenBoardState[planeCoreX - 2][planeCoreY] = 1;
        hiddenBoardState[planeCoreX - 2][planeCoreY + 1] = 1;
        hiddenBoardState[planeCoreX - 2][planeCoreY - 1] = 1;
    }

    // Populate the 'cross' in the plane
    hiddenBoardState[planeCoreX][planeCoreY] = 1;
    hiddenBoardState[planeCoreX + 1][planeCoreY] = 1;
    hiddenBoardState[planeCoreX - 1][planeCoreY] = 1;
    hiddenBoardState[planeCoreX][planeCoreY + 1] = 1;
    hiddenBoardState[planeCoreX][planeCoreY - 1] = 1;

    return hiddenBoardState;
  }

  Widget _buildGameBody() {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text('Plane Strike game based on TFLite'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _gridView(_buildAgentBoardItems),
            Text(
              "Agent's board (hits: $_playerHits)",
              style: TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            const Divider(
              height: 20,
              thickness: 5,
              indent: 20,
              endIndent: 20,
            ),
            Text(
              "Your board (hits: $_agentHits)",
              style: TextStyle(fontSize: 18, color: Colors.purple, fontWeight: FontWeight.bold),
            ),
            _gridView(_buildPlayerBoardItems),
            ElevatedButton(
              onPressed: () => setState(_resetGame),
              child: Text("Reset game"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridView(Widget Function(BuildContext context, int x, int y) itemBuilder) {
    return Builder(
      builder: (context) => Container(
        width: 265,
        height: 265,
        decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2.0)),
        child: GridView.count(
          crossAxisCount: _boardSize,
          children: [
            for (int i = 0; i < _boardSize; i++)
              for (int j = 0; j < _boardSize; j++) itemBuilder(context, i, j)
          ],
        ),
      ),
    );
  }

  Widget _buildAgentBoardItems(BuildContext context, int x, int y) {
    return GestureDetector(
      onTap: () => _gridItemTapped(context, x, y),
      child: _buildGridItem(x, y, 'agent'),
    );
  }

  Widget _buildPlayerBoardItems(BuildContext context, int x, int y) => _buildGridItem(x, y);

  Widget _buildGridItem(int x, int y, [String agentOrPlayer = 'player']) {
    var boardState = _agentBoardState;
    var hiddenBoardState = _agentHiddenBoardState;
    if (agentOrPlayer == 'player') {
      boardState = _playerBoardState;
      hiddenBoardState = _playerHiddenBoardState;
    }
    Color gridItemColor;
    switch ((boardState[x][y]).toInt()) {
      // hit
      case 1:
        gridItemColor = Colors.red;
        break;
      // miss
      case -1:
        gridItemColor = Colors.yellow;
        break;
      default:
        if (hiddenBoardState[x][y] == 1 && agentOrPlayer == 'player') {
          gridItemColor = Colors.green;
        } else {
          gridItemColor = Colors.white;
        }
    }

    return Container(
      decoration: BoxDecoration(
        color: gridItemColor,
        border: Border.all(color: Colors.black, width: 0.5),
      ),
    );
  }

  bool _takesAction(int x, int y, List<List<double>> boardList, List<List<double>> targetBoardList) {
    if (targetBoardList[x][y] == 1) {
      boardList[x][y] = 1;
      // Non-repeat move
      if (boardList[x][y] == 0) {
        return true;
      }
    } else {
      boardList[x][y] = -1;
    }

    return false;
  }

  /// 改为两次check success
  void _gridItemTapped(context, x, y) {
    if (_agentBoardState[x][y] != 0) {
      return;
    }

    setState(() {
      if (_takesAction(x, y, _agentBoardState, _agentHiddenBoardState)) {
        _playerHits++;
      }

      // Agent takes action
      int agentAction = _policyGradientAgent.predict(_playerBoardState);
      if (_takesAction(
          agentAction ~/ _boardSize, agentAction % _boardSize, _playerBoardState, _playerHiddenBoardState)) {
        _agentHits++;
      }
    });

    String userPrompt = '';
    if (_playerHits == _planePieceCount && _agentHits == _planePieceCount) {
      userPrompt = "Draw game!";
    } else if (_agentHits == _planePieceCount) {
      userPrompt = "Agent wins!";
    } else if (_playerHits == _planePieceCount) {
      userPrompt = "You win!";
    }

    if (userPrompt != '') {
      Future.delayed(const Duration(seconds: 2), () => setState(_resetGame));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userPrompt),
        duration: const Duration(seconds: 2),
      ));
    }
  }
}
