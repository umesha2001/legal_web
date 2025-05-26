import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class UserDash extends StatefulWidget {
  const UserDash({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<UserDash> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<UserDash> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 53, 62, 85),
      appBar: AppBar(
        title: Image.asset(
          'assets/images/civil-right.png',
          width: 30,
          height: 30,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 53, 62, 85),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(
            10.0,
          ), // Height of the bottom widget
          child: Container(
            color: const Color.fromARGB(
              255,
              53,
              62,
              85,
            ), // Background color of the bottom widget
            child: const Center(
              child: Text(
                'LEGAL WEB',
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 189, 181, 31),
                ),
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Container(
                  width: 300,
                  height: 250,
                  margin: const EdgeInsets.only(top: 20),

                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 217, 217, 217),
                  ),
                  child: ListView(
                    children: [
                      ListTile(title: Text('date :  2001-01-01')),
                      ListTile(title: Text('Meeting : 10:00 AM')),
                      ListTile(title: Text('Lawyer : John Doe')),
                      ListTile(title: Text('on call')),
                    ],
                  ),
                ),
              ],
            ),

            Card(
              margin: const EdgeInsets.only(top: 20),
              child: Container(
                width: 300,

                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 217, 217, 217),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text('lawyer name', textAlign: TextAlign.left),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Table(
                          border: TableBorder.all(),

                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: Color.fromARGB(192, 227, 234, 133),
                              ),
                              children: [
                                Center(child: Text('date')),
                                Center(child: Text('time')),
                                Center(child: Text('lawyer')),
                              ],
                            ),
                            TableRow(
                              decoration: BoxDecoration(
                                color: Color.fromARGB(192, 227, 220, 192),
                              ),
                              children: [
                                Text('2001-01-01'),
                                Text('10:00 AM'),
                                Text('John Doe'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        child: ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            ListTile(title: Text('Send files')),

                            Card(
                              child: ElevatedButton(
                                onPressed: () async {
                                  FilePickerResult? result =
                                      await FilePicker.platform.pickFiles();

                                  if (result != null &&
                                      result.files.single.path != null) {
                                    String? filePath = result.files.single.path;
                                    String fileName = result.files.single.name;

                                    final directory =
                                        await getApplicationDocumentsDirectory();
                                    final savePath =
                                        '${directory.path}/$fileName';

                                    File sourceFile = File(filePath!);
                                    await sourceFile.copy(savePath);

                                    print('File saved to: $savePath');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'File saved to: $savePath',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Text('Upload File'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF353E55),
        selectedItemColor: const Color(0xFFD0A554),
        unselectedItemColor: const Color(0xFFD9D9D9),
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/user-dash');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
