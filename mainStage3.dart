import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

void main() => runApp(MyApp());
/// This Widget is the main application widget.
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Home(),
    );
  }
}
class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}
class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Material(
        child: Scaffold(
          backgroundColor: Colors.green[200],
          appBar: AppBar(
          backgroundColor: Colors.green[700],
            title: Text('Welcome'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Text( // I used const Text to add spacing because I like how it looks
                    '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                    ),
                  ),
                  Image.asset('assets/bob.png'),
                  const Text(
                    '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                    ),
                  ),
                  MaterialButton( // button for user to click
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context)=>Screen2()));
                    },
                    color: Colors.green[700],
                    child: const Text("Let's Start", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class Screen2 extends StatefulWidget {
  @override
  _Screen2State createState() => _Screen2State();
}

class _Screen2State extends State<Screen2> {
  String name = '';
  String income = '';
  String budget = '';
  String frequency = ''; //no radio button will be selected on initial
  bool switchValue = false;
  String switchValueStr = '';
  String value = '';

  final nameController = TextEditingController();
  final incomeController = TextEditingController();
  final budgetController = TextEditingController();

  void updateName() {
    setState(() {
      name = nameController.text;
    });
  }

  void updateIncome() {
    setState(() {
      income = incomeController.text;
    });
  }

  void updateBudget() {
    setState(() {
      budget = budgetController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Material(
        child: Scaffold(
          backgroundColor: Colors.green[200],
          appBar: AppBar(
            title: Text('My Purchasing Habits'),
            backgroundColor: Colors.green[700],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Text(
                    'What is your name?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                    ),
                  ),

                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter name here: ',
                    ),
                  ),

                  const Text(
                    'Do you enjoy shopping?',
                    style: TextStyle(
                      fontSize: 30,
                    ),
                  ),

                  CupertinoSwitch(
                    value: switchValue,
                    activeColor: Colors.green[700],
                    onChanged: (value) {
                      setState(() {
                        switchValue = value;
                      });
                    },
                  ),

                  const Text(
                    'How often do you see yourself shopping?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                    ),
                  ),

                  RadioListTile(
                    title: Text("Rarely"),
                    value: "Rarely",
                    groupValue: frequency,
                    onChanged: (value){
                      setState(() {
                        frequency = value.toString();
                      });
                    },
                  ),
                  RadioListTile(
                    title: Text("Occasionally"),
                    value: "Occasionally",
                    groupValue: frequency,
                    onChanged: (value){
                      setState(() {
                        frequency = value.toString();
                      });
                    },
                  ),
                  RadioListTile(
                    title: Text("Frequently"),
                    value: "Frequently",
                    groupValue: frequency,
                    onChanged: (value){
                      setState(() {
                        frequency = value.toString();
                      });
                    },
                  ),

                  const Text(
                    'How much money do you make per month?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                    ),
                  ),

                  TextField(
                    controller: incomeController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter monthly income here',
                    ),
                  ),

                  const Text(
                    'How much money do you spend per month?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                    ),
                  ),

                  TextField(
                    controller: budgetController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter monthly spent dollar amount here',
                    ),
                  ),

                  MaterialButton( // button for user to click
                    onPressed: () {
                      updateName();
                      updateIncome();
                      updateBudget();
                      if (switchValue == true) {
                        switchValueStr = 'true';
                      }
                      else if (switchValue == false) {
                        switchValueStr = 'false';
                      }
                      Navigator.of(context).push(MaterialPageRoute(builder: (context)=>Final(
                        name: name,
                        income: income,
                        budget: budget,
                        frequency: frequency,
                        switchValueStr: switchValueStr,
                      )));
                    },
                    color: Colors.green[700],
                    child: const Text('View Answer', style: TextStyle(color: Colors.white)),
                  ),

                  MaterialButton( // button for user to click
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context)=>Home()));
                    },
                    color: Colors.green[700],
                    child: const Text('Go to Start Screen', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Final extends StatefulWidget {
  String name, income, budget, frequency, switchValueStr;
  Final({required this.name, required this.income, required this.budget, required this.frequency, required this.switchValueStr});

  @override
  _FinalState createState() => _FinalState();
}
class _FinalState extends State<Final> {
  String nameImport() {
    String name = widget.name;
    return name;
  }

  double convertIncome() {
   String income = widget.income;
   double inc = double.parse(income);
   return inc;
  }

  double convertBudget() {
    String budget = widget.budget;
    double bud = double.parse(budget);
    return bud;
  }

  String frequencyValue() {
    String frequency = widget.frequency;
    return frequency;
  }

  String switchImport() {
    String switchValue = widget.switchValueStr;
    return switchValue;
  }

  @override
  Widget build(BuildContext context) {
    String name = nameImport();
    double income = convertIncome();
    double budget = convertBudget();
    String frequency = frequencyValue();
    String switchValue = switchImport();

    String Answer = '';
    if((frequency == 'Rarely' || frequency == 'Occasionally') && income > budget) {
      Answer = 'Hey '+ name+', good job on managing your spending habits. Keep it up!';
    }
    else if((frequency == 'Frequently') && (income > budget) && (switchValue == 'true')) {
      Answer = 'Hey '+ name+', even though you enjoy shopping, it looks like you are doing great at managing your expenses.';
    }
    else if((frequency == 'Frequently') && (income > budget) && (switchValue == 'false')) {
      Answer = 'Hey '+ name+', it looks like you are doing great at managing your expenses.';
    }
    else if((income == budget)){
      Answer ='Hey '+ name+', you are at risk of being in debt. Make sure to monitor your spending habits.';
    }
    else if((income < budget) && (frequency != 'Frequently')){
      Answer ='Hey '+ name+', you are in debt and you need to cut back on your spending habits ASAP.';
    }
    else {
      Answer ='Attention '+ name+'! You have an addiction to spending money and you need to get help ASAP.';
    }

    return MaterialApp(
      home: Material(
        child: Scaffold(
          backgroundColor: Colors.green[200],
          appBar: AppBar(
            backgroundColor: Colors.green[700],
            title: Text('Answer Page'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [

                Text(
                  Answer,
                  style: TextStyle(
                    fontSize: 30,
                    ),
                  ),

                  MaterialButton( // button for user to click
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context)=>Screen2()));
                    },
                    color: Colors.green[700],
                    child: const Text('Go back', style: TextStyle(color: Colors.white)),
                  ),

                  MaterialButton( // button for user to click
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context)=>Home()));
                    },
                    color: Colors.green[700],
                    child: const Text('Go to Start Screen', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
