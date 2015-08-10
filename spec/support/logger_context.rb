shared_context :logger do

  def run_silently
    warn_level = $VERBOSE
    $VERBOSE = nil

    yield

    $VERBOSE = warn_level
  end

end
