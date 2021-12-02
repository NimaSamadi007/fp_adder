module fp_adder(a, b, s);

//*I/O NUMBERS*---------------------------------------------------------------------------------------------------------------------------------------------------\\

    input wire [31:0] a, b;
    output wire [31:0] s;
    
//*HIDDEN BIT DETECTION*------------------------------------------------------------------------------------------------------------------------------------------\\
 
    wire [25:0] hidden_a, hidden_b; 
    //dignose the hidden bit 1 or 0 (normalized or denormalized number)
    assign hidden_a = a[30:23] != 8'h00 ? {1'b1, a[22:0], 2'b00}:{1'b0, a[22:0], 2'b00};
    assign hidden_b = b[30:23] != 8'h00 ? {1'b1, b[22:0], 2'b00}:{1'b0, b[22:0], 2'b00};

//*SHIFTING SMALLER NUMBER*---------------------------------------------------------------------------------------------------------------------------------------\\
    
    //i consider 'a' is the bigger number and the 'b' is the smaller
    wire [7:0] number_of_shifts; // 8 bit for value for shifting (at most less than 255)
    wire carry_out; // i use carry out instead of borrow bit, of course : carry = ~ borrow
    wire [25:0] tmp_a, tmp_b; // tmp_b is the smaller number which is shifted by the diffrences of the exponents
    // assigning value of shift (subtraction of the numbers exponent)
    // if smaller number is denormalized so we consider it's exponent 1 (E = -126 not -127)
    assign number_of_shifts = a[30:23] > b[30:23] && b[30:23] != 8'h00 ? a[30:23] - b[30:23] :  
                              a[30:23] < b[30:23] && a[30:23] != 8'h00 ? b[30:23] - a[30:23] : 
                              a[30:23] > b[30:23] && b[30:23] == 8'h00 ? a[30:23] - 8'h01 : 
                              a[30:23] < b[30:23] && a[30:23] == 8'h00 ? b[30:23] - 8'h01 : 8'h00 ;
    // carry out is for checking that if my first guess is true or not ( a is the bigger and b is the smaller one)    
    assign carry_out =  a[30:23] >= b[30:23] ? 1'b1 : 1'b0;

    // if carry_out is 1 then borrow is 0 and there is no need to change number and vice versa
    assign tmp_a = carry_out != 1'b0 ? hidden_a : hidden_b ;
    assign tmp_b = carry_out != 1'b0 ? hidden_b >> number_of_shifts : hidden_a >> number_of_shifts;

//*STICKY BIT*----------------------------------------------------------------------------------------------------------------------------------------------------\\

    wire s_b; // s_b is sticky bit for smaller number, of course the bigger number's stikcy bit is zero because no shifting applied
    //finding the sticky bit
    assign s_b = (carry_out != 1'b0 && number_of_shifts > 2'b10) ? |(hidden_b ^ (( hidden_b >> number_of_shifts) << number_of_shifts)) :
                 (carry_out != 1'b0 && number_of_shifts <= 2'b10) ? 1'b0 :
                 (carry_out == 1'b0 && number_of_shifts > 2'b10) ? |(hidden_a ^ (( hidden_a >> number_of_shifts) << number_of_shifts)) : 
                 (carry_out == 1'b0 && number_of_shifts <= 2'b10) ? 1'b0 : 1'b0;

//*SIGN MAGINTUDE -> 2's COMPL.* ---------------------------------------------------------------------------------------------------------------------------------\\

    wire [27:0] final_a, final_b;
    // one bit (MSB) added for sign, and one bit for sticky bit added to (LSB).
    // this conditions are checking if the number swapped , so thier sign swapped too and i should consider it.
    assign final_a = a[30:23] >= b[30:23] && a[31] != 1'b0  ? {1'b1,-{tmp_a, 1'b0}} :
                     a[30:23] >= b[30:23] && a[31] == 1'b0 ? {1'b0, tmp_a, 1'b0} :
                     a[30:23] < b[30:23] && b[31] != 1'b0 ? {1'b1, -{tmp_b, s_b}} :
                     a[30:23] < b[30:23] && b[31] == 1'b0 ? {1'b0, tmp_b, s_b} : 0;
    
    assign final_b = a[30:23] >= b[30:23] && b[31] != 1'b0  ? {1'b1,-{tmp_b, s_b}} :
                     a[30:23] >= b[30:23] && b[31] == 1'b0 ? {1'b0, tmp_b, s_b} :
                     a[30:23] < b[30:23] && a[31] != 1'b0 ? {1'b1, -{tmp_a, 1'b0}} :
                     a[30:23] < b[30:23] && a[31] == 1'b0 ? {1'b0, tmp_a, 1'b0} : 0;

//*CALCULATION*---------------------------------------------------------------------------------------------------------------------------------------------------\\

    wire [28:0] compl_result;
    // sign extend two number and add them
    // the reason for needing a 29 bit adder is one bit should extended for prevnting overflow happening.
    assign compl_result = {final_a[27], final_a} + {final_b[27], final_b}; // adder - 29 bit 

//*2's COMPL. -> SIGN MAGNITUDE*------------------------------------------------------------------------------------------------------------------------------------\\

    //2's compl. to sign magnitude conversion
    wire [7:0] exponent; // exponent value till this section. 
    wire [27:0] m_result; // result in sign_magnitude format
    //sign detection - if the exponents were not same so the bigger number characterize the sign or result will characterize the sign.
    assign s[31] = (a[30:23] != b[30:23]) ? final_a[27] : compl_result[28]; 
    // we shift the decimal point to the left wo in normalize form , we shall add 1 to exponent but in denormalized form because we consider the exponent 1
    // so the exponoet will be 2 ( 1 is exponent -not zero- and add by one)
    assign exponent = ( a[30:23] > b[30:23] ) ? ( a[30:23] + 8'h01 ) : 
                      ( a[30:23] < b[30:23] ) ? ( b[30:23] + 8'h01 ) :
                      ( a[30:23] == b[30:23] && a[30:23] != 8'h00) ? ( a[30:23] + 8'h01 ) : 
                      ( a[30:23] == b[30:23] && a[30:23] == 8'h00) ? ( 8'h02 ) : 8'h02;
    // 2's compl. to sign magnitude conversion.
    // after this conversion the sign is deleted.
    assign m_result = compl_result[28] != 1 ? compl_result[27:0] : -compl_result[27:0];

//*DETECTION ON LEADING*--------------------------------------------------------------------------------------------------------------------------------------------\\

    wire [4:0] k; // highest possible Value is 27.
    assign {k} = m_result[27] ? {5'b1_1011} :
               m_result[26] ? {5'b1_1010} :
               m_result[25] ? {5'b1_1001} :
               m_result[24] ? {5'b1_1000} :
               m_result[23] ? {5'b1_0111} :
               m_result[22] ? {5'b1_0110} :
               m_result[21] ? {5'b1_0101} :
               m_result[20] ? {5'b1_0100} :
               m_result[19] ? {5'b1_0011} :
               m_result[18] ? {5'b1_0010} :
               m_result[17] ? {5'b1_0001} :
               m_result[16] ? {5'b1_0000} :
               m_result[15] ? {5'b0_1111} :
               m_result[14] ? {5'b0_1110} :
               m_result[13] ? {5'b0_1101} :
               m_result[12] ? {5'b0_1100} :
               m_result[11] ? {5'b0_1011} :
               m_result[10] ? {5'b0_1010} :
               m_result[9] ? {5'b0_1001} :
               m_result[8] ? {5'b0_1000} :
               m_result[7] ? {5'b0_0111} :
               m_result[6] ? {5'b0_0110} :
               m_result[5] ? {5'b0_0101} :
               m_result[4] ? {5'b0_0100} :
               m_result[3] ? {5'b0_0011} :
               m_result[2] ? {5'b0_0010} :
               m_result[1] ? {5'b0_0001} : {5'b0_0000};

//*NORMALIZING*-----------------------------------------------------------------------------------------------------------------------------------------------------\\

    wire [27:0] result; // normalized or de normalize form of m_result
    wire check_denorm; // for cchecking if in this section number is denormalized
    wire [7:0] before_final_exp; // changing the exponent

    // if we shift the number to the left and exponent remains bigger than 1 , so we can normalize the number
    // but if we can not normalize the number, by 'exponent - 1 ' value (cause the exponent should be 1 not zero -denormalized-) we shift the number
    assign result = (exponent > (27 - k)  ) ? m_result << (5'b1_1011 - k) : m_result << (exponent - 1);    
    // denormilization check - 1 for denorm and 0 for norm number
    assign check_denorm = (exponent > (27 - k) ) ? 1'b0 : 1'b1;
    // apply exponent changes
    assign before_final_exp = (check_denorm != 1'b0) ? 8'h00 : exponent - (5'b1_1011 - k) ;
    

//*ROUNDING*--------------------------------------------------------------------------------------------------------------------------------------------------------\\

    wire [24:0] rd_result; // this result have 2 bit before decimal point and 23 bit after that
    wire check_re_normalize; // for checjing that if after rounding the number needs to re normalizing 
    
    //rounding as instructions.
    // first condition says the the number after rounding point is bigger the 0.5, second condition is for 0.5 after rounding point and odd number
    // third condition is like the second one but it is for even number and in else section, the number don't need rounding
    assign rd_result = (result[3] && |result[2:0]) ? {1'b0, result[27:4]} + 25'b0_0000_0000_0000_0000_0000_0001 : 
                                            (result[3] && ~(|result[2:0]) && result[4]) ? {1'b0, result[27:4]} + 25'b0_0000_0000_0000_0000_0000_0001 :
                                            (result[3] && ~(|result[2:0]) && ~result[4]) ?  {1'b0, result[27:4]} : {1'b0, result[27:4]} ;
    assign check_re_normalize = rd_result[24]; // if the msb of rd_result is 1, it says that the number form is 10 . ....... so it is denormalized

//*RE NORMALIZING---------------------------------------------------------------------------------------------------------------------------------------------------\\

    wire [23:0] final_result; // it is final 24 bit reslut in this format : 1 . ........ or 0 . ......
    wire [7:0]  re_final_exp; // for exponent before the final exponent
    wire [7:0]  final_exp; // this is for the final exponent
    // the normalizing , at most, need 1 time to right
    assign final_result = check_re_normalize == 1'b1 ? rd_result >> 1 : rd_result;
    // and if we do the one time shift to right so we have to add exponent by one
    assign re_final_exp = check_re_normalize == 1'b1 ? before_final_exp + 1'b1 : before_final_exp ;
    // this for checking that if the fraction section is zero, so the final result is zero
    assign final_exp = (final_result == 24'b0000_0000_0000_0000_0000_0000) ? 8'h00 : re_final_exp ;

//*OUTPUT ASSIGNMNET*-----------------------------------------------------------------------------------------------------------------------------------------------\\

    //output assignment bits - if one of input is zero, the output result is the another number (this section is for more accuarcy)
    assign s[30:0] = (a[30:0] == 31'b000_0000_0000_0000_0000_0000_0000_0000) ? b[30:0] :
                     (b[30:0] == 31'b000_0000_0000_0000_0000_0000_0000_0000) ? a[30:0] : {final_exp, final_result[22:0]};

endmodule

