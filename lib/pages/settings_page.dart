import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.info),
            title: Text("About App"),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.bug_report),
            title: Text("Report a Bug"),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.help),
            title: Text("Help & Support"),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
