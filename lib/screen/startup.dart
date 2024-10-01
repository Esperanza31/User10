import 'package:flutter/material.dart';
import 'package:mini_project_five/pages/map_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartUpScreen extends StatefulWidget {
  @override
  _StartUpScreenState createState() => _StartUpScreenState();
}

class _StartUpScreenState extends State<StartUpScreen> {
  // List of organization names
  final List<String> organizations = [
    'Singapore Polytechnic',
    'Ngee Ann Polytechnic',
    'Republic Polytechnic',
    'Nanyang Polytechnic',
    'Temasek Polytechnic'
  ];

  // State to keep track of the selected checkbox
  int? selectedIndex;
  bool rememberChoice = false;

  @override
  void initState() {
    super.initState();
    _checkSavedSelection();
  }

  Future<void> _checkSavedSelection() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? savedIndex = prefs.getInt('selectedOrganization');
    bool? savedRememberChoice = prefs.getBool('rememberChoice');

    if (savedRememberChoice == true && savedIndex != null) {
      if (savedIndex == 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Map_Page()),
        );
      }
    }
  }

  Future<void> _saveSelection() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedOrganization', selectedIndex!);
    await prefs.setBool('rememberChoice', rememberChoice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Your Organization',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            // Generate checkboxes dynamically from the organizations list
            ...organizations.asMap().entries.map((entry) {
              int index = entry.key;
              String organization = entry.value;
              return CheckboxListTile(
                title: Text(organization),
                value: selectedIndex == index,
                onChanged: (bool? value) {
                  setState(() {
                    selectedIndex = value! ? index : null;
                  });
                },
              );
            }).toList(),
            SizedBox(height: 20),
            CheckboxListTile(
              title: Text("Remember my choice, don't ask me again"),
              value: rememberChoice,
              onChanged: (bool? value) {
                setState(() {
                  rememberChoice = value!;
                });
              },
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: selectedIndex != null
                    ? () {
                  if (selectedIndex == 1) {
                    if (rememberChoice) {
                      _saveSelection();
                    }
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Map_Page()),
                    );
                  }
                }
                    : null,
                child: Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
