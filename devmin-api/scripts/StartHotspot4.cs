using System;
using System.Collections.Generic;
using System.Threading;
using Windows.Foundation;
using Windows.Networking.Connectivity;
using Windows.Networking.NetworkOperators;

class Program {
  static T WaitOp<T>(IAsyncOperation<T> op, int timeoutMs) {
    var sw = System.Diagnostics.Stopwatch.StartNew();
    while (op.Status == AsyncStatus.Started) {
      if (sw.ElapsedMilliseconds > timeoutMs) throw new TimeoutException("timeout");
      Thread.Sleep(50);
    }
    if (op.Status == AsyncStatus.Error) throw op.ErrorCode;
    if (op.Status == AsyncStatus.Canceled) throw new OperationCanceledException();
    return op.GetResults();
  }

  // SoftAP manager must be created from a profile Windows accepts for tethering.
  // Prefer internet profile, then any profile where CreateFromConnectionProfile succeeds.
  // Do NOT prefer OpenVPN TAP alone — CreateFromConnectionProfile often fails on TAP.
  static NetworkOperatorTetheringManager CreateManager(out string profileName, out TetheringCapability capability) {
    profileName = null;
    capability = (TetheringCapability)0;

    var candidates = new List<ConnectionProfile>();
    ConnectionProfile internet = NetworkInformation.GetInternetConnectionProfile();
    if (internet != null) candidates.Add(internet);

    foreach (ConnectionProfile profile in NetworkInformation.GetConnectionProfiles()) {
      if (profile == null || string.IsNullOrEmpty(profile.ProfileName)) continue;
      bool duplicate = false;
      foreach (ConnectionProfile existing in candidates) {
        if (existing != null && string.Equals(existing.ProfileName, profile.ProfileName, StringComparison.OrdinalIgnoreCase)) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate) candidates.Add(profile);
    }

    Exception lastError = null;
    foreach (ConnectionProfile profile in candidates) {
      try {
        TetheringCapability cap = NetworkOperatorTetheringManager.GetTetheringCapabilityFromConnectionProfile(profile);
        if (cap != TetheringCapability.Enabled) {
          Console.WriteLine("skip profile=" + profile.ProfileName + " capability=" + cap);
          continue;
        }
        NetworkOperatorTetheringManager manager = NetworkOperatorTetheringManager.CreateFromConnectionProfile(profile);
        profileName = profile.ProfileName;
        capability = cap;
        return manager;
      } catch (Exception ex) {
        lastError = ex;
        Console.WriteLine("createFail profile=" + profile.ProfileName + " err=" + ex.Message);
      }
    }

    if (lastError != null) throw lastError;
    throw new InvalidOperationException("NO_TETHER_PROFILE");
  }

  static int Main(string[] args) {
    try {
      string profileName;
      TetheringCapability capability;
      NetworkOperatorTetheringManager tm = CreateManager(out profileName, out capability);
      Console.WriteLine("profile=" + profileName);
      Console.WriteLine("capability=" + capability);

      Console.WriteLine("state=" + tm.TetheringOperationalState);
      try {
        NetworkOperatorTetheringAccessPointConfiguration ap = tm.GetCurrentAccessPointConfiguration();
        Console.WriteLine("ssid=" + ap.Ssid + " auth=" + ap.AuthenticationKind);
      } catch (Exception ex) {
        Console.WriteLine("apcfg_err=" + ex.Message);
      }

      if (args.Length > 0 && args[0] == "status") return 0;
      if (tm.TetheringOperationalState == TetheringOperationalState.On) {
        Console.WriteLine("ALREADY_ON");
        return 0;
      }

      NetworkOperatorTetheringOperationResult result = WaitOp(tm.StartTetheringAsync(), 60000);
      Console.WriteLine("startStatus=" + result.Status);
      Console.WriteLine("stateAfter=" + tm.TetheringOperationalState);
      return (result.Status == TetheringOperationStatus.Success) ? 0 : 5;
    } catch (Exception ex) {
      Console.WriteLine("EX:" + ex);
      return 1;
    }
  }
}
