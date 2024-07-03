describe RelatonIec::DocumentType do
  it "warn if invalid doctype" do
    expect do
      RelatonIec::DocumentType.new type: "invalid"
    end.to output(/\[relaton-iec\] WARN: Invalid doctype: `invalid`/).to_stderr_from_any_process
  end
end
