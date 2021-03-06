RSpec.describe Relaton::Db do
  before :each do
    FileUtils.rm_rf %w(testcache testcache2)
    @db = Relaton::Db.new "testcache", "testcache2"
  end

  it "rejects an illegal reference prefix" do
    expect { @db.fetch("XYZ XYZ", nil, {}) }.to output(/does not have a recognised prefix/).to_stderr
  end

  context "gets an ISO reference" do
    it "and caches it" do
      VCR.use_cassette "iso_19115_1" do
        bib = @db.fetch("ISO 19115-1", nil, {})
        expect(bib).to be_instance_of RelatonIsoBib::IsoBibliographicItem
        expect(bib.to_xml(bibdata: true)).to include "<project-number>ISO 19115</project-number>"
        expect(File.exist?("testcache")).to be true
        expect(File.exist?("testcache2")).to be true
        testcache = Relaton::DbCache.new "testcache"
        expect(testcache["ISO(ISO 19115-1)"]).to include "<project-number>ISO 19115</project-number>"
        testcache = Relaton::DbCache.new "testcache2"
        expect(testcache["ISO(ISO 19115-1)"]).to include "<project-number>ISO 19115</project-number>"
      end
      bib = @db.fetch("ISO 19115-1", nil, {})
      expect(bib).to be_instance_of RelatonIsoBib::IsoBibliographicItem
    end

    it "with year in code" do
      VCR.use_cassette "19133_2005" do
        bib = @db.fetch("ISO 19133:2005")
        expect(bib).to be_instance_of RelatonIsoBib::IsoBibliographicItem
        expect(bib.to_xml).to include '<bibitem id="ISO19133-2005" type="standard">'
        testcache = Relaton::DbCache.new "testcache"
        expect(testcache.valid_entry?("ISO(ISO 19133:2005)", Date.today.year.to_s)).to eq Date.today.year.to_s
      end
    end

    context "all parts" do
      it "implicity" do
        VCR.use_cassette "iso_19115" do
          bib = @db.fetch("ISO 19115", nil, {})
          expect(bib).to be_instance_of RelatonIsoBib::IsoBibliographicItem
        end
      end

      it "explicity" do
        VCR.use_cassette "iso_19115" do
          bib = @db.fetch("ISO 19115 (all parts)", nil, {})
          expect(bib).to be_instance_of RelatonIsoBib::IsoBibliographicItem
        end
      end
    end
  end

  it "gets sn ISO/AWI reference" do
    VCR.use_cassette "iso_awi_24229" do
      bib = @db.fetch "ISO/AWI 24229"
      expect(bib).not_to be_nil
    end
  end

  context "NIST references" do
    it "gets FISP" do
      VCR.use_cassette "fisp_140" do
        bib = @db.fetch "NIST FIPS 140"
        expect(bib).to be_instance_of RelatonNist::NistBibliographicItem
      end
    end

    it "gets SP" do
      VCR.use_cassette "sp_800_38b" do
        bib = @db.fetch "NIST SP 800-38B"
        expect(bib).to be_instance_of RelatonNist::NistBibliographicItem
      end
    end
  end

  it "deals with a non-existant ISO reference" do
    VCR.use_cassette "iso_111111119115_1" do
      bib = @db.fetch("ISO 111111119115-1", nil, {})
      expect(bib).to be_nil
      expect(File.exist?("testcache")).to be true
      expect(File.exist?("testcache2")).to be true
      testcache = Relaton::DbCache.new "testcache"
      expect(testcache.fetched("ISO(ISO 111111119115-1)")).to eq Date.today.to_s
      expect(testcache["ISO(ISO 111111119115-1)"]).to include "not_found"
      testcache = Relaton::DbCache.new "testcache2"
      expect(testcache.fetched("ISO(ISO 111111119115-1)")).to eq Date.today.to_s
      expect(testcache["ISO(ISO 111111119115-1)"]).to include "not_found"
    end
  end

  it "list all elements as a serialization" do
    VCR.use_cassette "iso_19115_1_2", match_requests_on: [:path] do
      @db.fetch "ISO 19115-1", nil, {}
      @db.fetch "ISO 19115-2", nil, {}
    end
    # file = "spec/support/list_entries.xml"
    # File.write file, @db.to_xml unless File.exist? file
    docs = Nokogiri::XML @db.to_xml
    expect(docs.xpath("/documents/bibdata").size).to eq 2
  end

  it "save/load/delete entry" do
    @db.save_entry "test key", "test value"
    expect(@db.load_entry("test key")).to eq "test value"
    expect(@db.load_entry("not existed key")).to be_nil
    @db.save_entry "test key", nil
    expect(@db.load_entry("test key")).to be_nil
    testcache = Relaton::DbCache.new "testcache"
    testcache.delete("test_key")
    testcache2 = Relaton::DbCache.new "testcache2"
    testcache2.delete("test_key")
    expect(@db.load_entry("test key")).to be_nil
  end

  context "get GB reference" do
    it "and cache it" do
      VCR.use_cassette "gb_t_20223_2006" do
        bib = @db.fetch "CN(GB/T 20223)", "2006", {}
        expect(bib).to be_instance_of RelatonGb::GbBibliographicItem
        expect(bib.to_xml(bibdata: true)).to include "<project-number>GB/T 20223</project-number>"
        expect(File.exist?("testcache")).to be true
        expect(File.exist?("testcache2")).to be true
        testcache = Relaton::DbCache.new "testcache"
        expect(testcache["CN(GB/T 20223:2006)"]).to include "<project-number>GB/T 20223</project-number>"
        testcache = Relaton::DbCache.new "testcache2"
        expect(testcache["CN(GB/T 20223:2006)"]).to include "<project-number>GB/T 20223</project-number>"
      end
    end

    it "with year" do
      VCR.use_cassette "gb_t_20223_2006" do
        bib = @db.fetch "CN(GB/T 20223-2006)", nil, {}
        expect(bib).to be_instance_of RelatonGb::GbBibliographicItem
        expect(bib.to_xml(bibdata: true)).to include "<project-number>GB/T 20223</project-number>"
        expect(File.exist?("testcache")).to be true
        expect(File.exist?("testcache2")).to be true
        testcache = Relaton::DbCache.new "testcache"
        expect(testcache["CN(GB/T 20223:2006)"]).to include "<project-number>GB/T 20223</project-number>"
        testcache = Relaton::DbCache.new "testcache2"
        expect(testcache["CN(GB/T 20223:2006)"]).to include "<project-number>GB/T 20223</project-number>"
      end
    end
  end

  it "get RFC reference and cache it" do
    VCR.use_cassette "rfc_8341" do
      bib = @db.fetch "RFC 8341", nil, {}
      expect(bib).to be_instance_of RelatonIetf::IetfBibliographicItem
      expect(bib.to_xml).to include "<bibitem id=\"RFC8341\" type=\"standard\">"
      expect(File.exist?("testcache")).to be true
      expect(File.exist?("testcache2")).to be true
      testcache = Relaton::DbCache.new "testcache"
      expect(testcache["IETF(RFC 8341)"]).to include "<docidentifier type=\"IETF\">RFC 8341</docidentifier>"
      testcache = Relaton::DbCache.new "testcache2"
      expect(testcache["IETF(RFC 8341)"]).to include "<docidentifier type=\"IETF\">RFC 8341</docidentifier>"
    end
  end

  it "get OGC refrence and cache it" do
    VCR.use_cassette "ogc_19_025r1" do
      bib = @db.fetch "OGC 19-025r1", nil, {}
      expect(bib).to be_instance_of RelatonOgc::OgcBibliographicItem
    end
  end

  it "get Calconnect refrence and cache it" do
    VCR.use_cassette "cc_dir_10005_2019", match_requests_on: [:path] do
      bib = @db.fetch "CC/DIR 10005:2019", nil, {}
      expect(bib).to be_instance_of RelatonCalconnect::CcBibliographicItem
    end
  end

  it "get OMG reference" do
    VCR.use_cassette "ogm_ami4ccm_1_0" do
      bib = @db.fetch "OMG AMI4CCM 1.0", nil, {}
      expect(bib).to be_instance_of RelatonOmg::OmgBibliographicItem
    end
  end

  it "get UN reference" do
    VCR.use_cassette "un_rtade_cefact_2004_32" do
      bib = @db.fetch "UN TRADE/CEFACT/2004/32", nil, {}
      expect(bib).to be_instance_of RelatonUn::UnBibliographicItem
    end
  end

  it "get W3C reference" do
    VCR.use_cassette "w3c_json_ld11" do
      bib = @db.fetch "W3C JSON-LD 1.1", nil, {}
      expect(bib).to be_instance_of RelatonW3c::W3cBibliographicItem
    end
  end

  it "get IEEE reference" do
    VCR.use_cassette "ieee_528_2019" do
      bib = @db.fetch "IEEE 528-2019"
      expect(bib).to be_instance_of RelatonIeee::IeeeBibliographicItem
    end
  end

  it "get IHO reference" do
    VCR.use_cassette "iho_b_11" do
      bib = @db.fetch "IHO B-11"
      expect(bib).to be_instance_of RelatonIho::IhoBibliographicItem
    end
  end

  context "version control" do
    before(:each) { @db.save_entry "iso(test_key)", value: "test_value" }

    it "shoudn't clear cacho if version isn't changed" do
      db = Relaton::Db.new "testcache", "testcache2"
      testcache = db.instance_variable_get :@db
      expect(testcache.all).to be_any
      testcache = db.instance_variable_get :@local_db
      expect(testcache.all).to be_any
    end

    it "should clear cache if version is changed" do
      expect(File.exist?("testcache")).to be true
      expect(File.exist?("testcache2")).to be true
      processor = double
      expect(processor).to receive(:grammar_hash).and_return("new_version").exactly(2).times
      expect(Relaton::Registry.instance).to receive(:by_type).and_return(processor).exactly(2).times
      db = Relaton::Db.new "testcache", "testcache2"
      testcache = db.instance_variable_get :@db
      expect(testcache.all).not_to be_any
      testcache = db.instance_variable_get :@local_db
      expect(testcache.all).not_to be_any
    end
  end
end
