# return activecheck version
java = "/usr/bin/java"
jar = "/usr/share/activecheck/activecheck.jar"
if FileTest.exists?(java) and FileTest.exists?(jar)
  Facter.add("activecheck_version") do
    version = Facter::Util::Resolution.exec("#{java} -jar #{jar} -version | head -1")
    setcode do
      if match = /^([0-9]+.[0-9]+.[0-9]+)$/.match(version)
        match[1]
      else
        nil
      end
    end
  end
end
