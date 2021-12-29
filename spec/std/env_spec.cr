require "spec"
require "./spec_helper"
require "../support/env"

describe "ENV" do
  it "gets non existent key raises" do
    expect_raises KeyError, "Missing ENV key: \"NON-EXISTENT\"" do
      ENV["NON-EXISTENT"]
    end
  end

  it "gets non existent key as nilable" do
    ENV["NON-EXISTENT"]?.should be_nil
  end

  it "set and gets" do
    (ENV["FOO"] = "1").should eq("1")
    ENV["FOO"].should eq("1")
    ENV["FOO"]?.should eq("1")
  ensure
    ENV.delete("FOO")
  end

  {% if flag?(:win32) %}
    it "sets and gets case-insensitive" do
      (ENV["FOO"] = "1").should eq("1")
      ENV["Foo"].should eq("1")
      ENV["foo"]?.should eq("1")
    ensure
      ENV.delete("FOO")
    end
  {% else %}
    it "sets and gets case-sensitive" do
      ENV["FOO"] = "1"
      ENV["foo"]?.should be_nil
    ensure
      ENV.delete("FOO")
    end
  {% end %}

  it "sets to nil (same as delete)" do
    ENV["FOO"] = "1"
    ENV["FOO"]?.should_not be_nil
    ENV["FOO"] = nil
    ENV["FOO"]?.should be_nil
  end

  it "sets to empty string" do
    (ENV["FOO_EMPTY"] = "").should eq ""
    ENV["FOO_EMPTY"]?.should eq ""
  ensure
    ENV.delete("FOO_EMPTY")
  end

  it "does has_key?" do
    ENV["FOO"] = "1"
    ENV.has_key?("NON_EXISTENT").should be_false
    ENV.has_key?("FOO").should be_true
  ensure
    ENV.delete("FOO")
  end

  it "deletes a key" do
    ENV["FOO"] = "1"
    ENV.delete("FOO").should eq("1")
    ENV.delete("FOO").should be_nil
    ENV.has_key?("FOO").should be_false
  end

  it "does .keys" do
    %w(FOO BAR).each { |k| ENV.keys.should_not contain(k) }
    ENV["FOO"] = ENV["BAR"] = "1"
    %w(FOO BAR).each { |k| ENV.keys.should contain(k) }
  ensure
    ENV.delete("FOO")
    ENV.delete("BAR")
  end

  it "does not have an empty key" do
    # Setting an empty key is invalid on both POSIX and Windows. So reporting an empty key
    # would always be a bug. And there *was* a bug - see win32/ Crystal::System::Env.each
    ENV.keys.should_not contain("")
  end

  it "does .values" do
    [1, 2].each { |i| ENV.values.should_not contain("SOMEVALUE_#{i}") }
    ENV["FOO"] = "SOMEVALUE_1"
    ENV["BAR"] = "SOMEVALUE_2"
    [1, 2].each { |i| ENV.values.should contain("SOMEVALUE_#{i}") }
  ensure
    ENV.delete("FOO")
    ENV.delete("BAR")
  end

  describe "[]=" do
    it "disallows NUL-bytes in key" do
      expect_raises(ArgumentError, "String `key` contains null byte") do
        ENV["FOO\0BAR"] = "something"
      end
    end

    it "disallows NUL-bytes in key if value is nil" do
      expect_raises(ArgumentError, "String `key` contains null byte") do
        ENV["FOO\0BAR"] = nil
      end
    end

    it "disallows NUL-bytes in value" do
      expect_raises(ArgumentError, "String `value` contains null byte") do
        ENV["FOO"] = "BAR\0BAZ"
      end
    end
  end

  describe "fetch" do
    it "fetches with one argument" do
      ENV["1"] = "2"
      ENV.fetch("1").should eq("2")
    ensure
      ENV.delete("1")
    end

    it "fetches with default value" do
      ENV["1"] = "2"
      ENV.fetch("1", "3").should eq("2")
      ENV.fetch("2", "3").should eq("3")
    ensure
      ENV.delete("1")
    end

    it "fetches with block" do
      ENV["1"] = "2"
      ENV.fetch("1") { |k| k + "block" }.should eq("2")
      ENV.fetch("2") { |k| k + "block" }.should eq("2block")
    ensure
      ENV.delete("1")
    end

    it "fetches and raises" do
      ENV["1"] = "2"
      expect_raises KeyError, "Missing ENV key: \"2\"" do
        ENV.fetch("2")
      end
    ensure
      ENV.delete("1")
    end
  end

  it "handles unicode" do
    ENV["TEST_UNICODE_1"] = "bar\u{d7ff}\u{10000}"
    ENV["TEST_UNICODE_2"] = "\u{1234}"
    ENV["TEST_UNICODE_1"].should eq "bar\u{d7ff}\u{10000}"
    ENV["TEST_UNICODE_2"].should eq "\u{1234}"

    values = {} of String => String
    ENV.each do |key, value|
      if key.starts_with?("TEST_UNICODE_")
        values[key] = value
      end
    end
    values.should eq({
      "TEST_UNICODE_1" => "bar\u{d7ff}\u{10000}",
      "TEST_UNICODE_2" => "\u{1234}",
    })
  ensure
    ENV.delete("TEST_UNICODE_1")
    ENV.delete("TEST_UNICODE_2")
  end

  it "#to_h" do
    ENV["FOO"] = "foo"
    ENV.to_h["FOO"].should eq "foo"
  ensure
    ENV.delete("FOO")
  end

  it "clears the env" do
    tempenv = { "PATH" => "/foo/bar:/baz/buz", "DUMMY_VAR" => "dummy_value" }
    with_env(tempenv) do
      ENV.should_not be_empty      
      ENV.clear
      ENV.should be_empty
    end

  end

  it "replaces the env with a hash" do
    tempenv = { "PATH1" => "/foo/bar:/baz/buz", "DUMMY_VAR" => "dummy_value" }
    newenv = { "PATH2" => "/oof/rab:/zab/zub", "DUMMY_TWO" => "another_value" }
    with_env(tempenv) do
      ENV.has_key?("PATH1").should be_true
      ENV.has_key?("DUMMY_VAR").should be_true
      ENV.replace(newenv)
      ENV.has_key?("PATH1").should be_false
      ENV.has_key?("DUMMY_VAR").should be_false
      ENV.has_key?("PATH2").should be_true
      ENV.has_key?("DUMMY_TWO").should be_true
    end
  end
  
  describe "merge" do
    it "merges with overwrite" do
      ENV["TEST_MERGE_1"] = "1"
      ENV["TEST_MERGE_2"] = "2"
      merge_hash = {
        "TEST_MERGE_1" => "one",
        "TEST_MERGE_3" => "three",
      }
      ENV.merge! merge_hash
      ENV.fetch("TEST_MERGE_1").should eq "one"
      ENV.fetch("TEST_MERGE_2").should eq "2"
      ENV.fetch("TEST_MERGE_3").should eq "three"
    ensure
      ENV.delete("TEST_MERGE_1")
      ENV.delete("TEST_MERGE_2")
      ENV.delete("TEST_MERGE_3")
    end

    it "merges with a block" do
      temp_env = {
        "TEST_MERGE_AAA" => "1",
        "TEST_MERGE_BBB" => "2",
        "TEST_MERGE_CCC" => "3",
        "TEST_MERGE_DDD" => "4",
        "TEST_MERGE_FFF" => "6",
      }

      merge_hash = {
        "TEST_MERGE_AAA" => "aa",
        "TEST_MERGE_BBB" => "bb",
        "TEST_MERGE_CCC" => "cc",
        "TEST_MERGE_EEE" => "ee",
        "TEST_MERGE_FFF" => "ffff",
        "TEST_MERGE_GGG" => "keep",
      }

      with_env(temp_env) do
        ENV.merge!(merge_hash) do |name, old, new|
          case name
          when /AAA/ then old
          when /BBB/ then new
          when /CCC/ then nil
          when /FFF/ then old + new
          else            name
          end
        end
        ENV.fetch("TEST_MERGE_AAA").should eq "1"  # old
        ENV.fetch("TEST_MERGE_BBB").should eq "bb" # new
        ENV.has_key?("TEST_MERGE_CCC").should be_false # removal (nil) case
        ENV.fetch("TEST_MERGE_DDD").should eq "4" # not a collision, value from original env
        ENV.fetch("TEST_MERGE_EEE").should eq "ee"
        ENV.fetch("TEST_MERGE_FFF").should eq "6ffff" # old + new
        ENV.fetch("TEST_MERGE_GGG").should eq "keep" # not a collision, value from new hash
      end
    end
  end
end
