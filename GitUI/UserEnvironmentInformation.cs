﻿using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using GitCommands;
using GitExtUtils.GitUI;

namespace GitUI
{
    public static class UserEnvironmentInformation
    {
        private static bool _alreadySet;
        private static bool _dirty;
        private static string _sha;

        public static void CopyInformation() => Clipboard.SetText(GetInformation());

        public static string GetInformation()
        {
            if (!_alreadySet)
            {
                throw new InvalidOperationException($"{nameof(Initialise)} must be called first");
            }

            string gitVer;
            try
            {
                gitVer = GitVersion.Current?.Full ?? "";
            }
            catch (Exception)
            {
                gitVer = "";
            }

            // Build and open FormAbout design to make sure info still looks good if you change this code.
            StringBuilder sb = new StringBuilder();

            sb.AppendLine($"- Git Extensions {AppSettings.ProductVersion}");
            sb.AppendLine($"- Build {_sha.Substring(0, 9)}{(_dirty ? " (Dirty)" : "")}");
            sb.AppendLine($"- Git {gitVer}");
            sb.AppendLine($"- {Environment.OSVersion}");
            sb.AppendLine($"- {RuntimeInformation.FrameworkDescription}");
            sb.AppendLine($"- DPI {DpiUtil.DpiX}dpi ({(DpiUtil.ScaleX == 1 ? "no" : $"{Math.Round(DpiUtil.ScaleX * 100)}%")} scaling)");

            return sb.ToString();
        }

        public static void Initialise(string sha, bool isDirty)
        {
            if (_alreadySet)
            {
                return;
            }

            _alreadySet = true;
            _sha = sha;
            _dirty = isDirty;
        }
    }
}