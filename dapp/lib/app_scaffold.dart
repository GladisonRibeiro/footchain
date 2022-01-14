import 'package:dapp/commands/account/set_current_account_command.dart';
import 'package:dapp/commands/contracts/load_contracts_command.dart';
import 'package:dapp/commands/init_app_command.dart';
import 'package:dapp/models/app_model.dart';
import 'package:dapp/views/main_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web3/flutter_web3.dart';
import 'package:provider/src/provider.dart';

import 'views/login_view.dart';
import 'views/splash_view.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({Key? key}) : super(key: key);

  @override
  _AppScaffoldState createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _loadingApp = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() async {
    if (Ethereum.isSupported) {
      print("ETHEREUM DISPONIVEL");
      requestUserConnectAccount();

      ethereum!.onAccountsChanged((accs) {
        print("nova conta");
        SetCurrentAccountCommand().execute(accs.first);
      });
    } else {
      print("ETHEREUM NAO DISPONIVEL");
    }
    setState(() {
      _loadingApp = false;
    });
  }

  Future requestUserConnectAccount() async {
    try {
      final accs = await ethereum!.requestAccount();
      if (accs.isNotEmpty) {
        await InitAppCommand().execute(provider, accs.first);
      }
    } on Exception catch (e) {
      // TODO
      print("USUARIO CANCELOU");
    }
  }

  @override
  Widget build(BuildContext context) {
    String? currentAccount =
        context.select<AppModel, String?>((value) => value.currentAccount);
    if (_loadingApp) {
      return const SplashView();
    } else {
      if (currentAccount != null) {
        return const MainView();
      } else {
        return const LoginView();
      }
    }
  }
}
