defmodule Membrane.Agora.Sink do
  use Membrane.Sink

  alias Membrane.Agora.Sink.Native

  def_input_pad(:video_input, accepted_format: %Membrane.H264{alignment: :au}, flow_control: :auto)

  def_options(
    app_id: [spec: String.t()],
    token: [spec: String.t()],
    channel_name: [spec: String.t()],
    user_id: [spec: String.t()]
  )

  @impl true
  def handle_init(_ctx, opts) do
    {:ok, native_state} = Native.create(opts.app_id, opts.token, opts.channel_name, opts.user_id)

    {[], %{native_state: native_state}}
  end

  @impl true
  def handle_stream_format(:video_input, stream_format, _ctx, state) do
    framerate =
      case stream_format.framerate do
        {frames, seconds} -> :erlang.round(frames / seconds)
        _other -> 30
      end

    {:ok, native_state} =
      Native.update_stream_format(
        stream_format.height,
        stream_format.width,
        framerate,
        state.native_state
      )

    state = %{native_state: native_state}
    {[], state}
  end

  @impl true
  def handle_buffer(:video_input, buffer, _ctx, state) do
    pts = Membrane.Time.round_to_milliseconds(buffer.pts)
    dts = Membrane.Time.round_to_milliseconds(buffer.dts)

    :ok =
      Native.write_data(
        buffer.payload,
        buffer.metadata.h264.key_frame?,
        pts,
        dts,
        state.native_state
      )

    {[], state}
  end
end
