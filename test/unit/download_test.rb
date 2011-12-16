require 'test_helper'

class DownloadTest < ActiveSupport::TestCase
  should "load up all downloads with just raw strings and process them" do
    rubygem = Factory(:rubygem, :name => "some-stupid13-gem42-9000")
    version = Factory(:version, :rubygem => rubygem)

    3.times do
      Download.incr(rubygem.name, version.full_name)
    end

    assert_equal 3, version.downloads_count
    assert_equal 3, rubygem.downloads
    assert_equal 3, Download.count
    assert_equal 3, Download.today(version)
  end

  should "track platform gem downloads correctly" do
    rubygem = Factory(:rubygem)
    version = Factory(:version, :rubygem => rubygem, :platform => "mswin32-60")
    other_platform_version = Factory(:version, :rubygem => rubygem, :platform => "mswin32")

    Download.incr(rubygem.name, version.full_name)

    assert_equal 1, version.downloads_count
    assert_equal 1, rubygem.downloads
    assert_equal 0, other_platform_version.downloads_count

    assert_equal 1, Download.count
    assert_equal 1, Download.today(version)
    assert_equal 0, Download.today(other_platform_version)
  end

  should "find most downloaded today" do
    @rubygem_1 = Factory(:rubygem)
    @version_1 = Factory(:version, :rubygem => @rubygem_1)
    @version_2 = Factory(:version, :rubygem => @rubygem_1)

    @rubygem_2 = Factory(:rubygem)
    @version_3 = Factory(:version, :rubygem => @rubygem_2)

    @rubygem_3 = Factory(:rubygem)
    @version_4 = Factory(:version, :rubygem => @rubygem_3)

    Timecop.freeze(Date.today - 1) do
      Download.incr(@rubygem_1.name, @version_1.full_name)
      Download.incr(@rubygem_1.name, @version_2.full_name)
      Download.incr(@rubygem_2.name, @version_3.full_name)
    end

    Download.incr(@rubygem_1.name, @version_1.full_name)
    3.times { Download.incr(@rubygem_2.name, @version_3.full_name) }
    2.times { Download.incr(@rubygem_1.name, @version_2.full_name) }

    assert_equal [[@version_3, 3], [@version_2, 2], [@version_1, 1]],
                 Download.most_downloaded_today

    assert_equal [[@version_3, 3], [@version_2, 2]],
                 Download.most_downloaded_today(2)

    assert_equal 3, Download.cardinality
    assert_equal 1, Download.rank(@version_3)
    assert_equal 2, Download.rank(@version_2)
    assert_equal 3, Download.rank(@version_1)

    assert_equal 3, Download.today([@version_1, @version_2])
    assert_equal 2, Download.highest_rank([@version_1, @version_2])
    assert_equal 1, Download.highest_rank([@version_3])
    assert_equal 1, Download.highest_rank([@version_3, @version_4])
  end

  should "find most downloaded all time" do
    @rubygem_1 = Factory(:rubygem)
    @version_1 = Factory(:version, :rubygem => @rubygem_1)
    @version_2 = Factory(:version, :rubygem => @rubygem_1)

    @rubygem_2 = Factory(:rubygem)
    @version_3 = Factory(:version, :rubygem => @rubygem_2)

    @rubygem_3 = Factory(:rubygem)
    @version_4 = Factory(:version, :rubygem => @rubygem_3)

    Download.incr(@rubygem_1.name, @version_1.full_name)
    Download.incr(@rubygem_1.name, @version_2.full_name)
    Download.incr(@rubygem_2.name, @version_3.full_name)
    Download.incr(@rubygem_1.name, @version_1.full_name)
    3.times { Download.incr(@rubygem_2.name, @version_3.full_name) }
    2.times { Download.incr(@rubygem_1.name, @version_2.full_name) }

    assert_equal [[@version_3, 4], [@version_2, 3], [@version_1, 2]],
                 Download.most_downloaded_all_time

    assert_equal [[@version_3, 4], [@version_2, 3]],
                 Download.most_downloaded_all_time(2)

    assert_equal 3, Download.cardinality
    assert_equal 1, Download.rank(@version_3)
    assert_equal 2, Download.rank(@version_2)
    assert_equal 3, Download.rank(@version_1)

  end

  should "find counts per day for versions" do
    @rubygem_1 = Factory(:rubygem)
    @version_1 = Factory(:version, :rubygem => @rubygem_1)
    @version_2 = Factory(:version, :rubygem => @rubygem_1)

    @rubygem_2 = Factory(:rubygem)
    @version_3 = Factory(:version, :rubygem => @rubygem_2)

    @rubygem_3 = Factory(:rubygem)
    @version_4 = Factory(:version, :rubygem => @rubygem_3)

    Timecop.freeze(1.day.ago) do
      Download.incr(@rubygem_1, @version_1.full_name)
      Download.incr(@rubygem_1, @version_2.full_name)
      Download.incr(@rubygem_2, @version_3.full_name)
    end

    Download.incr(@rubygem_2, @version_3.full_name)
    Download.incr(@rubygem_1, @version_1.full_name)
    Download.incr(@rubygem_2, @version_3.full_name)
    Download.incr(@rubygem_2, @version_3.full_name)
    Download.incr(@rubygem_1, @version_2.full_name)

    downloads = {
      "#{@version_1.id}-#{2.days.ago.to_date}" => 0, "#{@version_1.id}-#{Date.yesterday}" => 1, "#{@version_1.id}-#{Time.zone.today}" => 1,
      "#{@version_2.id}-#{2.days.ago.to_date}" => 0, "#{@version_2.id}-#{Date.yesterday}" => 1, "#{@version_2.id}-#{Time.zone.today}" => 1,
      "#{@version_3.id}-#{2.days.ago.to_date}" => 0, "#{@version_3.id}-#{Date.yesterday}" => 1, "#{@version_3.id}-#{Time.zone.today}" => 3 }

    assert_equal downloads.size, 9
    assert_equal downloads, Download.counts_by_day_for_versions([@version_1, @version_2, @version_3], 2)
  end

  should "find download count by gem name" do
    rubygem = Factory(:rubygem)
    version1 = Factory(:version, :rubygem => rubygem)
    version2 = Factory(:version, :rubygem => rubygem)

    3.times { Download.incr(rubygem.name, version1.full_name) }
    2.times { Download.incr(rubygem.name, version2.full_name) }

    assert_equal 5, Download.for_rubygem(rubygem.name)
    assert_equal 3, Download.for_version(version1.full_name)
    assert_equal 2, Download.for_version(version2.full_name)
  end

  should "return zero for rank if no downloads exist" do
    assert_equal 0, Download.rank(FactoryGirl.build(:version))
  end

  should "return zero for highest rank the given versions have zero downloads" do
    assert_equal 0, Download.highest_rank([FactoryGirl.build(:version), FactoryGirl.build(:version)])
  end

  should "delete all old today keys except the current" do
    rubygem = Factory(:rubygem)
    version = Factory(:version, :rubygem => rubygem)
    10.times do |n|
      Timecop.freeze(n.days.ago) do
        3.times { Download.incr(rubygem.name, version.full_name) }
      end
    end
    assert_equal 9, Download.today_keys.size
    Download.cleanup_today_keys
    assert_equal 0, Download.today_keys.size
  end
end
