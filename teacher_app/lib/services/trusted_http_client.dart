import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Some Android devices/OS builds don't yet trust the newer CA that issues the backend's TLS
/// certificate, even though the cert itself is valid (browsers on the same device work fine because
/// they ship their own, more frequently updated, trust store). Explicitly trusting the exact
/// intermediate + root the server presents - on top of the platform's normal trusted roots - fixes
/// that without disabling certificate validation.
Future<http.Client> createTrustedHttpClient() async {
  final securityContext = SecurityContext(withTrustedRoots: true);
  try {
    final certData = await rootBundle.load('assets/certs/render_trust_chain.pem');
    securityContext.setTrustedCertificatesBytes(certData.buffer.asUint8List());
  } catch (_) {
    // Falls back to the platform's default trusted roots only.
  }
  return IOClient(HttpClient(context: securityContext));
}
