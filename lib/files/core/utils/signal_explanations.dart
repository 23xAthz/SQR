class SignalInfo {
  final String why;
  final String example;

  const SignalInfo({required this.why, required this.example});
}

const signalInfoMap = {
  'Unencrypted connection (HTTP instead of HTTPS)': SignalInfo(
    why: 'Data over HTTP can be intercepted by attackers.',
    example: 'Fake login page stealing credentials over public WiFi.',
  ),

  'URL uses a raw IP address instead of a domain name': SignalInfo(
    why: 'IP-based URLs bypass trust and reputation systems.',
    example: 'http://192.168.1.1/login pretending to be a bank.',
  ),

  'URL is a known shortener - final destination is hidden': SignalInfo(
    why: 'Shortened links hide the real destination.',
    example: 'bit.ly redirecting to phishing page.',
  ),

  'Punycode or homograph characters detected in domain': SignalInfo(
    why: 'Visually similar characters mimic trusted domains.',
    example: 'paypaI.com (capital i instead of l).',
  ),

  'Executable file detected — may install malicious software': SignalInfo(
    why: 'Executable files can install malware.',
    example: 'Fake APK installing spyware.',
  ),

  'Direct file download detected — may trigger automatic download': SignalInfo(
    why: 'Files may download without clear warning.',
    example: 'Malicious PDF exploiting vulnerabilities.',
  ),

  'URL contains download-related parameters': SignalInfo(
    why: 'Indicates possible hidden file delivery.',
    example: 'download.php?file=invoice.pdf',
  ),
};