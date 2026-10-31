/************************************************************\
**	Copyright (c) 2012-2024 Anlogic Inc.
**	All Right Reserved.\
\************************************************************/
/************************************************************\
**	Build time: Jun 30 2024 17:42:42
**	TD version	:	5.9.112584
\************************************************************/
module system_Concat_0
(
  input   [0:0]                 In0,
  input   [0:0]                 In1,
  input   [13:0]                In2,
  output  [15:0]                Dout
);

  concat_2bf5f1584592
  #(
      .PORT_NUM(3),
      .IN_WIDTH_0(1),
      .IN_WIDTH_1(1),
      .IN_WIDTH_2(14),
      .OUT_WIDTH(16)
  )concat_2bf5f1584592_Inst
  (
      .In0(In0),
      .In1(In1),
      .In2(In2),
      .Dout(Dout)
  );
endmodule
