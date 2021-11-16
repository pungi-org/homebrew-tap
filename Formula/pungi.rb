class Pungi < Formula
  desc "A charming way to manage Python versions."
  homepage "https://github.com/pungi-org/pungi"
  url "https://github.com/pungi-org/pungi/archive/refs/tags/v0.3.1.tar.gz"
  sha256 "812e47c70aaae56002c78faafb9014353929cb3ddcd302a6596a14d8e65bf2fc"
  license "MIT"
  version_scheme 1
  head "https://github.com/pungi-org/pungi.git", branch: "trunk"
  conflicts_with "pyenv", because: "Pungi is a pyenv fork, they can't both manage Python"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "autoconf"
  depends_on "openssl@1.1"
  depends_on "pkg-config"
  depends_on "readline"

  uses_from_macos "bzip2"
  uses_from_macos "libffi"
  uses_from_macos "ncurses"
  uses_from_macos "xz"
  uses_from_macos "zlib"

  on_linux do
    depends_on "python@3.9" => :test
  end

  def install
    inreplace "libexec/pungi", "/usr/local", HOMEBREW_PREFIX
    inreplace "libexec/pungi-rehash", "$(command -v pungi)", opt_bin/"pungi"
    inreplace "pungi.d/rehash/source.bash", "$(command -v pungi)", opt_bin/"pungi"

    system "src/configure"
    system "make", "-C", "src"

    prefix.install Dir["*"]
    %w[pungi-install pungi-uninstall python-build].each do |cmd|
      bin.install_symlink "#{prefix}/plugins/python-build/bin/#{cmd}"
    end

    share.install prefix/"man"

    # Do not manually install shell completions. See:
    #   - https://github.com/pyenv/pyenv/issues/1056#issuecomment-356818337
    #   - https://github.com/Homebrew/homebrew-core/pull/22727
  end

  test do
    # Create a fake python version and executable.
    pungi_root = Pathname(shell_output("pungi root").strip)
    python_bin = pungi_root/"versions/1.2.3/bin"
    foo_script = python_bin/"foo"
    foo_script.write "echo hello"
    chmod "+x", foo_script

    # Test versions.
    versions = shell_output("eval \"$(#{bin}/pungi init --path)\" " \
                            "&& eval \"$(#{bin}/pungi init -)\" " \
                            "&& pungi versions").split("\n")
    assert_equal 2, versions.length
    assert_match(/\* system/, versions[0])
    assert_equal("  1.2.3", versions[1])

    # Test rehash.
    system "pungi", "rehash"
    refute_match "Cellar", (pungi_root/"shims/foo").read
    assert_equal "hello", shell_output("eval \"$(#{bin}/pungi init --path)\" " \
                                       "&& eval \"$(#{bin}/pungi init -)\" " \
                                       "&& PUNGI_VERSION='1.2.3' foo").chomp
  end
end
