class Maconky < Formula
  desc "Conky for Mac — native desktop HUD"
  homepage "https://github.com/giozenone/maconky"
  head "https://github.com/giozenone/maconky.git", branch: "main"

  depends_on macos: :sonoma
  depends_on xcode: ["16.0", :build]

  def install
    system "make", "ARCHS=#{Hardware::CPU.arch}", "app"
    prefix.install "Maconky.app"
  end

  def caveats
    <<~EOS
      Maconky is a menu bar extra, compiled on this Mac.
        open #{opt_prefix}/Maconky.app
    EOS
  end

  test do
    assert_predicate prefix/"Maconky.app/Contents/MacOS/Maconky", :executable?
  end
end
