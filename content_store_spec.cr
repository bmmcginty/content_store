require "spec"
require "./content_store"

dn=File.dirname(File.readlink("/proc/self/exe"))
`rm -Rf "#{dn}/data"`
describe "contentstore" do
it "works" do
a=Repo.new "a"
t=a.open "i1"
t.list.should eq Array(String).new
t.exists?("a1").should eq false
t.write "a1","content1"
t.exists?("a1").should eq true
t.list.should eq ["a1"]
t.close
t=a.open "i1"
t.list.should eq ["a1"]
t.read("a1").should eq "content1"
t.write("a1","content2")
t.close
t=a.open "i1"
t.list.should eq ["a1"]
t.read("a1").should eq "content2"
t.write("a2","content1")
t.list.should eq ["a1","a2"]
t.close
a.close
end
it "errors on adding repo outside of repo dir" do
expect_raises(ContentStoreBoundaryError) do
a=Repo.new "../outside_repo_dir_repo"
end
end
it "errors on adding file with dots" do
a=Repo.new "repo_containing_file_with_dots"
expect_raises(ContentStoreBoundaryError) do
t=a.open "../i1"
end # expect
end # it
it "removes existing tmpdir" do
`touch data/site/a1`
`touch data/site/a1/d1.tmpdir`
a=Repo.new "a1"
i=a.open "d1"
File.exists?("data/site/a1/d1.tmpdir").should eq false
i.close
a.close
end
it "removes existing tmpfile" do
`touch data/site/a1`
`touch data/site/a1/f1.tmpfile`
a=Repo.new "a1"
i=a.open "f1"
File.exists?("data/site/a1/f1.tmpfile").should eq false
i.close
a.close
end
it "handles large files" do
a=Repo.new "big"
i=a.open "huge"
st1=Time.monotonic
Dir.children("/tmp/gg").each do |name|
i.write name,File.read("/tmp/gg/"+name)
end
st2=Time.monotonic
i.close
st3=Time.monotonic
puts "write #{st2-st1}"
puts "compress #{st3-st2}"
a.close
end
end # describe
