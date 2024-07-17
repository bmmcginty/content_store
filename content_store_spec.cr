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
it "decompresses to directory" do
a=Repo.new "a"
i=a.open "i1"
Dir.mkdir_p "/dev/shm/d1"
i.decompress "/dev/shm/d1"
Dir.children("/dev/shm/d1").sort.should eq ["a1","a2"]
FileUtils.rm_r("/dev/shm/d1")
i.close
a.close
end
it "removes existing tmpdir when requested to do so" do
p="data/site/a1/d1.tar.zstd.tmpdir"
`mkdir -p #{p}`
a=Repo.new "a1"
i=a.open "d1", ensure_clean: true
File.exists?(p).should eq false
i.close
a.close
end
it "does not remove tempdir normally" do
p="data/site/a1/d2.tar.zstd.tmpdir"
`mkdir -p #{p}`
a=Repo.new "a1"
i=a.open "d2"
File.exists?(p).should eq true
i.close
a.close
end
it "removes existing tmpfile" do
p="data/site/a1/f1.tar.zstd.tmpfile"
`mkdir data/site/a1`
`touch #{p}`
a=Repo.new "a1"
i=a.open "f1"
File.exists?(p).should eq false
i.close
a.close
end
it "converts" do
a=Repo.new "big.com"
i=a.open "gg"
i.convert("/tmp/gg").should eq true
i.convert("/tmp/gg").should eq false
i.convert("/tmp/dir-that-does-not-exist").should eq false
i.close
a.close
end # it
it "handles large files" do
`mkdir -p data/site/big.com`
`cp -p -R /tmp/gg data/site/big.com/huge`
a=Repo.new "big.com"
i=a.open "huge"
st1=Time.monotonic
i.convert
st2=Time.monotonic
i.close
st3=Time.monotonic
puts "convert #{st2-st1}"
puts "compress #{st3-st2}"
a.close
end # it
it "tests quick methods" do
ContentStore.open "test.com/chapter/1" do |i|
i.write "a1", "content1"
end # item
File.exists?("data/site/test.com/chapter/1.tar.zstd").should eq true
end # it
end # describe
