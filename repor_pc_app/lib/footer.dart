import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.grey.shade200,
      child: const Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "UJAP - Facultad de Ingeniería - Escuela de Ingeniería de Computación",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}