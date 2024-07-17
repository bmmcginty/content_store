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
end # describe
