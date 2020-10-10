/*************************************************************************************************************************
 Company       : 
 Owner         :
 Project Name  : 
 Description   : This module is for video format detection.
 Version       : 1.0
 Module Name   : vdo_format_detect
 Modifications :
*************************************************************************************************************************/
`timescale 1ns / 1ps

module vdo_format_detect (
  // axi stream clock and reset
  input         aclk,
  input         aresetn,
  // video input interface
  input         s_axis_video_tlast, // eol
  input         s_axis_video_tuser, // sof
  input         s_axis_video_tvalid,
  // video output interface
  output logic [11:0] pxlCnt,
  output logic [11:0] latchPxlCnt,
  output logic [11:0] lnCnt,
  output logic [11:0] latchLnCnt,
	output logic        oneSecPulse,
  output logic [5:0]  frameCnt,
	output logic [12:0] avgPxlCnt,
	output logic [12:0] avgLnCnt,
	output logic [1:0]  frameFormat // 00--> NO VIDEO, 01--> 1080p@60, 10--> 4k@30, 11--> 4k@60
);

// enumerated state for frame resolution and rate
enum bit [1:0] {NOVIDEO=2'd0,P60AT1080=2'd1,P30AT4K=2'd2,P60AT4K=2'd3} frameReslRate;

// logic
logic        rst;
logic [15:0] primaryCnt;
logic [12:0] secondaryCnt;
logic [02:0] secondsCnt;

// design reset
assign rst = !aresetn;

//************************************************************************************************************************
// Pixel count per line
//************************************************************************************************************************
always_ff @(posedge aclk) begin
  if(rst) begin
    pxlCnt <= 0;
    latchPxlCnt <= 0;
  end else if(s_axis_video_tlast & s_axis_video_tvalid) begin
    pxlCnt <= 0;
    latchPxlCnt <= pxlCnt;
  end else if(s_axis_video_tvalid) begin	
	  pxlCnt <= pxlCnt + 11'd1;
    latchPxlCnt <= latchPxlCnt;
  end
end

//************************************************************************************************************************
// Line count per frame
//************************************************************************************************************************
always_ff @(posedge aclk) begin
  if(rst) begin
    lnCnt <= 0;
    latchLnCnt <= 0;
  end else if(s_axis_video_tuser & s_axis_video_tvalid) begin
    lnCnt <= 0;
    latchLnCnt <= lnCnt;
  end else if(s_axis_video_tlast & s_axis_video_tvalid) begin	
	  lnCnt <= lnCnt + 11'd1;
    latchLnCnt <= latchLnCnt;
  end
end

//************************************************************************************************************************
// One Second count
//************************************************************************************************************************
always_ff @(posedge aclk) begin
  if(rst) begin
    primaryCnt <= 0;
  end else begin
	  primaryCnt <= primaryCnt + 16'd1;
  end
end

always_ff @(posedge aclk) begin
  if(rst) begin
    secondaryCnt <= 0;
  end else if(oneSecPulse) begin
    secondaryCnt <= 0;
  end else if(primaryCnt==16'hffff) begin
	  secondaryCnt <= secondaryCnt + 13'd1;
  end
end

always_ff @(posedge aclk) begin
  if(rst) begin
    oneSecPulse <= 0;
  end else if((secondaryCnt==13'd4578) & (!oneSecPulse)) begin
//  end else if((secondaryCnt==13'd800) & (!oneSecPulse)) begin
    oneSecPulse <= 1;
  end else begin
	  oneSecPulse <= 0;
  end
end

always_ff @(posedge aclk) begin
  if(rst) begin
    secondsCnt <= 0;
  end else if(oneSecPulse) begin
    secondsCnt <= secondsCnt + 3'd1;
  end
end

//************************************************************************************************************************
// Frame rate count per second
//************************************************************************************************************************
always_ff @(posedge aclk) begin
  if(rst) begin
    frameCnt <= 0;
	end else if(oneSecPulse) begin
    frameCnt <= 0;
  end else if(s_axis_video_tuser & s_axis_video_tvalid & (frameCnt<6'd63)) begin
	  frameCnt <= frameCnt + 6'd1;
  end
end

//************************************************************************************************************************
// Resolution detect
//************************************************************************************************************************
// average pixel count per line
always_ff @(posedge aclk) begin
  if(rst) begin
    avgPxlCnt <= 0;
  end else if(lnCnt>11'd2) begin
    if(s_axis_video_tlast & s_axis_video_tvalid) begin	
	    avgPxlCnt <= (pxlCnt + latchPxlCnt)>>1;
		end
  end
end

// average line count per frame
always_ff @(posedge aclk) begin
  if(rst) begin
    avgLnCnt <= 0;
  end else if(frameCnt>6'd2) begin
    if(s_axis_video_tuser & s_axis_video_tvalid) begin	
	    avgLnCnt <= (lnCnt + latchLnCnt)>>1;
		end
  end
end

// identify frame resolution and rate
always_ff @(posedge aclk) begin
  if(rst) begin
    frameReslRate <= NOVIDEO;
  end else if(oneSecPulse & (secondsCnt>3'd1)) begin
    if((avgPxlCnt==13'd0) | (avgLnCnt==13'd0)) begin
      frameReslRate <= NOVIDEO;
    // 2 pixels per clock
		end else if((avgPxlCnt<=13'd1280) & (avgLnCnt<=13'd1600)) begin
	    frameReslRate <= P60AT1080;
    // 2 pixels per clock
		end else if((avgPxlCnt>13'd1900) & (avgLnCnt>13'd1600)) begin
//      if(frameCnt>6'd31) begin
//      if(frameCnt>6'd2)begin
	      frameReslRate <= P60AT4K;
//			end else begin
//	      frameReslRate <= P30AT4K;
//      end
		end else begin
	    frameReslRate <= frameReslRate;
		end
  end
end

// frame format
assign frameFormat = frameReslRate;

endmodule