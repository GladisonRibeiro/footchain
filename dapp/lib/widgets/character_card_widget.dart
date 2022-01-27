import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web3/flutter_web3.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../commands/contracts/nft/player/get_player_begin_time_training_command.dart';
import '../commands/contracts/nft/player/get_player_detail_command.dart';
import '../commands/contracts/nft/player/get_player_training_status_command.dart';
import '../commands/contracts/nft/player/get_player_uri_by_id_command.dart';
import '../commands/contracts/nft/player/player_generate_metadata_command.dart';
import '../commands/training/player/finish_training_command.dart';
import '../commands/training/player/start_training_command.dart';
import '../dto/character_dto.dart';
import '../localizations/custom_localizations.dart';
import '../utils/constants/constants.dart';
import '../utils/get_character_image.dart';
import '../utils/utils.dart';

class CharacterCardWidget extends StatefulWidget {
  final BigInt tokenId;

  const CharacterCardWidget({Key? key, required this.tokenId})
      : super(key: key);

  @override
  State<CharacterCardWidget> createState() => _CharacterCardWidgetState();
}

class _CharacterCardWidgetState extends State<CharacterCardWidget> {
  var _executingTransaction = false;
  var _executingMint = false;
  final ValueNotifier<bool> _inTraining = ValueNotifier<bool>(false);
  String? _tokenUri;
  BigInt? _tokenIdUri;
  final thirtyMinutes = 30 * 60;
  final ValueNotifier<int> _remainingTrainingDurationInSeconds =
      ValueNotifier<int>(30 * 60);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    initWidget();
  }

  void initWidget() async {
    var uri = await GetPlayerUriByIdCommand().execute(widget.tokenId);
    setState(() {
      _tokenUri = uri.replaceFirst('ipfs://', '');
      _tokenIdUri = BigInt.tryParse(_tokenUri!);
    });
    if (_tokenIdUri == null) {
      _checkTraining();
    }
  }

  void _checkTraining() async {
    var inTraining =
        await GetPlayerTrainingStatusCommand().execute(widget.tokenId);

    _inTraining.value = inTraining;

    if (_inTraining.value == true) {
      var begin =
          await GetPlayerBeginTimeTrainingCommand().execute(widget.tokenId);

      var beginTime = DateTime.fromMillisecondsSinceEpoch(begin.toInt() * 1000);

      var diff = DateTime.now().difference(beginTime);
      var remainingTraining = thirtyMinutes - diff.inSeconds;

      if (remainingTraining < 0) {
        _remainingTrainingDurationInSeconds.value = 0;
        _timer?.cancel();
      } else {
        _remainingTrainingDurationInSeconds.value = remainingTraining;
        _createTimer();
      }
    }
  }

  void _createTimer() {
    if (_timer != null) {
      _timer?.cancel();
    }

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (_remainingTrainingDurationInSeconds.value == 0) {
          setState(() {
            timer.cancel();
          });
        } else {
          _remainingTrainingDurationInSeconds.value--;
        }
      },
    );
  }

  void _generateMetadata() async {
    setState(() {
      _executingMint = true;
    });
    var txHash = await PlayerGenerateMetadataCommand().execute(_tokenIdUri!);

    if (txHash.isNotEmpty) {
      showSnackbarMessage(text: txHash);
      await provider!.waitForTransaction(txHash);
      var uri = await GetPlayerUriByIdCommand().execute(_tokenIdUri!);
      if (uri.isNotEmpty) {
        setState(() {
          _tokenUri = uri.replaceFirst('ipfs://', '');
          _tokenIdUri = null;
        });
      }
    } else {
      showSnackbarMessage(
          text: CustomLocalizations.of(context).genericErrorMessage);
    }

    setState(() {
      _executingMint = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_executingMint || _tokenUri == null) {
      return _loadingWidget();
    }

    if (_tokenIdUri != null) {
      return _box();
    }

    if (_tokenUri != null && _tokenUri!.isNotEmpty) {
      return FutureBuilder<CharacterDto>(
        future: GetPlayerDetailCommand().execute(_tokenUri!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loadingWidget();
          }

          if (snapshot.data == null) {
            return const Text('No content');
          }

          final CharacterDto character = snapshot.data!;

          return _card(character);
        },
      );
    }

    return const Text('No content');
  }

  Widget _loadingWidget() {
    return const SizedBox(
      width: 230,
      height: 300,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _box() {
    return GestureDetector(
      onTap: _generateMetadata,
      child: Container(
        width: 230,
        height: 300,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.white, width: 5),
          borderRadius: borderRadiusAll,
          boxShadow: const [boxShadow],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('#$_tokenIdUri'),
              const FaIcon(FontAwesomeIcons.futbol, size: 56),
              const SizedBox(height: 32),
              Text(
                CustomLocalizations.of(context).openBoxButton,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(CharacterDto character) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: colorByRarity(character.rarity), width: 5),
        borderRadius: borderRadiusAll,
        boxShadow: const [boxShadow],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            child: Text(
              '#$_tokenUri',
              style: const TextStyle(fontSize: 6),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            child: Text(
              '${character.name}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorByRarity(character.rarity),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            height: 162,
            child: Center(
              child: Container(
                alignment: Alignment.center,
                height: 130,
                child: Center(
                  child: Image.network(
                    getCharacterImage(character),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 25,
            child: Center(
              child: Text(
                character.rarity?.toUpperCase() ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: colorByRarity(character.rarity),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 25,
            child: Center(
              child: Row(
                children: [
                  const Text(
                    'Nivel: 1',
                    style: TextStyle(fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: borderRadiusAll,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 25,
                            child: Container(
                              width: 10,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: colorPrimary,
                                borderRadius: borderRadiusAll,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 75,
                            child: SizedBox(),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: colorByRarity(character.rarity))),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🔥',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      child: Text(
                        '${character.attack!.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🛡️',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      child: Text(
                        '${character.defense!.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🤫',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      child: Text(
                        '${character.creativity!.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🕴️',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      child: Text(
                        '${character.tactic!.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🦶',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      child: Text(
                        '${character.technique!.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: colorByRarity(character.rarity))),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '🗻',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 5),
                    Text('${character.height!.value}'),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '👣 ',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 5),
                    Text('${character.preferredFoot}'),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '🚶‍♂️ ',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 5),
                    Text('${character.position}')
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          actions(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget actions() {
    void _startTraining() async {
      try {
        setState(() {
          _executingTransaction = true;
          _inTraining.value = true;
        });
        final resultApprove =
            await StartTrainingCommand().execute(widget.tokenId);
        setState(() {
          showSnackbarMessage(text: resultApprove);
          _executingTransaction = false;
          _remainingTrainingDurationInSeconds.value = thirtyMinutes;
          _createTimer();
        });
      } on EthereumException catch (e) {
        setState(() {
          _executingTransaction = false;
          showSnackbarMessage(text: e.data["message"]);
        });
      }
    }

    Widget _btnStartTraining = ElevatedButton(
      child: _executingTransaction
          ? const Center(child: CircularProgressIndicator())
          : Text(
              CustomLocalizations.of(context).startTrainingButton,
              style: const TextStyle(fontSize: 14),
            ),
      onPressed: _executingTransaction ? null : _startTraining,
    );

    void _finishTraining() async {
      try {
        setState(() {
          _executingTransaction = true;
        });
        final resultApprove =
            await FinishTrainingCommand().execute(widget.tokenId);
        setState(() {
          showSnackbarMessage(text: resultApprove);
          _executingTransaction = false;
          _inTraining.value = false;
        });
      } on EthereumException catch (e) {
        setState(() {
          _executingTransaction = false;
          showSnackbarMessage(text: e.data["message"]);
        });
      }
    }

    Widget _btnEndTraining = ValueListenableBuilder<int>(
      valueListenable: _remainingTrainingDurationInSeconds,
      builder: (context, remainingTraining, child) {
        return ElevatedButton(
          child: _executingTransaction
              ? const Center(child: CircularProgressIndicator())
              : Opacity(
                  opacity: remainingTraining > 0 ? 0.75 : 1,
                  child: Text(
                    remainingTraining > 0
                        ? '${(Duration(seconds: remainingTraining))}'
                            .split('.')[0]
                            .padLeft(8, '0')
                        : 'Finish',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
          onPressed: _executingTransaction || remainingTraining > 0
              ? null
              : _finishTraining,
        );
      },
    );

    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<bool>(
              valueListenable: _inTraining,
              builder: (context, inTraining, child) {
                return SizedBox(
                    height: 45,
                    child: (inTraining ? _btnEndTraining : _btnStartTraining));
              }),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
