#@String czi_file
#@String xml_out

run("Make CZI Dataset for BigStitcher", 
	"czi_file=["+czi_file+"] "+
	"erase_if_file_already_exists=true "+
	"xml_out=["+xml_out+"]");